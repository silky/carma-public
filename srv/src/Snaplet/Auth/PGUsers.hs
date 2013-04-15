{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}

{-|

Postgres-based roles & user meta storage for Snap authentication
system.

Roles are stored in @usermetatbl@ table as created from the @usermeta@
model.

Populating user roles and meta from PG:

> Just u <- with auth currentUser
> u' <- with db $ replaceMetaRolesFromPG u

-}

module Snaplet.Auth.PGUsers
    ( -- * User roles & meta
      userRolesPG
    , UserMeta(..)
    , userMetaPG
    , replaceMetaRolesFromPG
      -- * List of all users
    , UsersList(..)
    , usersListPG
    )

where

import Control.Applicative

import Data.Aeson
import Data.Aeson.TH
import Data.ByteString.Char8 (ByteString, pack)
import Data.Text (Text)
import Data.Text.Encoding
import Data.Maybe
import Data.Map as M hiding (map)
import Data.HashMap.Strict as HM (HashMap, fromList)

import Database.PostgreSQL.Simple.FromField
import Database.PostgreSQL.Simple.SqlQQ

import Snap.Snaplet.Auth hiding (session)
import Snap.Snaplet.PostgresqlSimple

import qualified Data.Vector as V

import Snaplet.DbLayer as DB
import Snaplet.DbLayer.Types


-- | A usermeta instance converted to a HashMap used by legacy user
-- meta of Snap authentication system.
--
-- HashMap values are guaranteed to use 'String' constructor of
-- 'Value'.
--
-- The following fields of usermeta are not present: @login@, @uid@.
--
-- New fields added: @mid@ for usermeta id, @value@ for login, @label@
-- for realName.
newtype UserMeta = UserMeta (HashMap Text Value) deriving (Show, ToJSON)


instance FromField [Role] where
    fromField f dat = (map Role . V.toList) <$> fromField f dat


------------------------------------------------------------------------------
-- | Select meta for a user with uid given as a query parameter.
userRolesQuery :: Query
userRolesQuery = [sql|
SELECT roles FROM usermetatbl WHERE uid=?;
|]


------------------------------------------------------------------------------
-- | Select meta id for a user with uid given as a query parameter.
userMidQuery :: Query
userMidQuery = [sql|
SELECT id FROM usermetatbl WHERE uid=?;
|]


------------------------------------------------------------------------------
-- | Select logins and metas for all users.
allUsersQuery :: Query
allUsersQuery = [sql|
SELECT u.login, m.* FROM usermetatbl m, snap_auth_user u WHERE u.uid=m.uid;
|]


------------------------------------------------------------------------------
-- | Convert a usermeta instance as read from DbLayer to use with
-- Snap.
toSnapMeta :: Map ByteString ByteString -> HashMap Text Value
toSnapMeta usermeta =
    HM.fromList $
    map (\(k, v) -> (decodeUtf8 k, String $ decodeUtf8 v)) $
    M.toList $
    -- Strip internal fields
    M.delete "login" $
    M.delete "uid" $
    M.delete "id" $
    -- Add user meta id under mid key
    M.insert "mid" (usermeta ! "id") $
    -- Add dictionary-like fields (map login to realName)
    M.insert "value" login $
    M.insert "label" (fromMaybe login $ M.lookup "realName" usermeta) $
    usermeta
    where
      login = usermeta ! "login"


------------------------------------------------------------------------------
-- | List of entries for all users present in the database, used to
-- serve user DB to client.
--
-- Previously known as @UsersDict@.
data UsersList = UsersList [UserMeta]
                 deriving (Show)

$(deriveToJSON id ''UsersList)


------------------------------------------------------------------------------
-- | Get list of roles from the database for a user.
userRolesPG :: HasPostgres m => AuthUser -> m [Role]
userRolesPG user =
    case userId user of
      Nothing -> return []
      Just (UserId uid) -> do
        rows <- query userRolesQuery (Only uid)
        return $ case rows of
          ((e:_):_) -> e
          _     -> []


------------------------------------------------------------------------------
-- | Get meta from the database for a user.
userMetaPG :: AuthUser -> DbHandler b (Maybe UserMeta)
userMetaPG user =
    case userId user of
      Nothing -> return Nothing
      Just (UserId uid) -> do
        mid' <- query userMidQuery (Only uid)
        case mid' of
          (((mid :: Int):_):_) -> do
            -- This will read usermeta instance from Redis. If we
            -- could only read Postgres rows to commits.
            res <- DB.read "usermeta" $ pack $ show mid
            return $ Just $ UserMeta $ toSnapMeta res
          _     -> return Nothing


------------------------------------------------------------------------------
-- | Get list of all users from the database.
usersListPG :: HasPostgres m => m UsersList
usersListPG = do
  return $ UsersList []


------------------------------------------------------------------------------
-- | Replace roles and meta for a user with those stored in Postgres.
replaceMetaRolesFromPG :: AuthUser -> DbHandler b AuthUser
replaceMetaRolesFromPG user = do
  ur <- userRolesPG user
  umRes <- userMetaPG user
  let um' = case umRes of
              Just (UserMeta um) -> um
              Nothing -> userMeta user
  return user{userRoles = ur, userMeta = um'}
