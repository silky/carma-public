{-# LANGUAGE ScopedTypeVariables, QuasiQuotes, FlexibleContexts #-}

module Utils.Events where

import           Prelude hiding (log)

import           Control.Monad
import           Control.Monad.RWS

import           Data.String (fromString)
import           Text.Printf

import           Data.Maybe
import           Data.Text (Text)
import qualified Data.Text as T
import           Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as B

import           GHC.TypeLits

import           Data.Model
import           Data.Model.Patch (Patch)
import qualified Data.Model.Patch     as P
import qualified Data.Model.Patch.Sql as P

import           Snap
import           Snap.Snaplet.Auth
import           Snaplet.Auth.Class
import           Snap.Snaplet.PostgresqlSimple ( HasPostgres(..)
                                               , query
                                               , Only(..)
                                               )
import           Database.PostgreSQL.Simple.SqlQQ

import           Carma.Model
import           Carma.Model.Event (Event, EventType(..))
import qualified Carma.Model.Event     as E
import           Carma.Model.UserState (UserState, UserStateVal(..))
import qualified Carma.Model.UserState as State
import           Carma.Model.Usermeta  (Usermeta)
import           Carma.Model.Action    (Action)
import qualified Carma.Model.Action as Action
import qualified Carma.Model.Call   as Call

import           Snaplet.Search.Types

import           Util
import           Utils.LegacyModel


-- | Create `Event` for login/logout fact
logLogin :: (HasPostgres (Handler b m), HasAuth b)
         => EventType -> Handler b m ()
logLogin tpe = do
  uid <- getRealUid
  _   <- log $ addIdent uid $ buildEmpty tpe
  return ()

-- | Interface for events from legacy CRUD
logLegacyCRUD :: (HasPostgres (Handler b b1), HasAuth b, Model m, SingI n)
              => EventType
              -- ^ event type
              -> ByteString
              -- ^ Legacy object identifier `model:id`
              -> (m -> F t n d)
              -- ^ Changed field
              -> Handler b b1 ()
logLegacyCRUD tpe mdl fld = log $ buildLegacy tpe mdl fld

-- | Create event from patch and change user state when needed
log :: (HasPostgres (Handler b m), HasAuth b) => Patch Event -> Handler b m ()
log p = do
  uid <- getRealUid
  id' <- create $ setUsr uid p
  let p' = P.put E.ident id' p
  checkUserState uid p'
  return ()

-- Implementation --------------------------------------------------------------

-- | Build `Path Event`
buildFull :: forall m t n d.(Model m, SingI n)
          => EventType
          -- ^ Type of the event
          -> IdentI m
          -- ^ Identifier of model `m`, emitted event
          -> Maybe (m -> F t n d)
          -- ^ Changed field
          -- -> Maybe (Patch m)
          -- ^ The whole patch
          -- FIXME: can't save patch, because current crud using bad types
          -> Patch Event
buildFull tpe idt f =
  P.put E.modelId   mid   $
  P.put E.modelName mname $
  P.put E.field     fname $
  -- P.put E.patch     patch' $
  buildEmpty tpe
   where
     mname = modelName $ (modelInfo :: ModelInfo m)
     mid   = identVal idt
     fname = return . fieldName =<< f
     -- patch' = Just $ toJSON patch

-- | Build `Patch Event` with just user and type
buildEmpty :: EventType -> Patch Event
buildEmpty tpe = P.put E.eventType tpe $  P.empty

-- | Create `Event` in `postgres` from `Patch Event`, return it's id
create :: HasPostgres m
       => Patch Event
       -> m (IdentI Event)
create ev = withPG $ \c -> liftIO $ P.create ev c

-- | Log event for legacy model crud
buildLegacy :: forall m t n d.(Model m, SingI n)
            => EventType
            -- ^ Type of the event
            -> ByteString
            -- ^ legacy id `model:id`
            -> (m -> F t n d)
            -- ^ Changed field
            -> Patch Event
buildLegacy tpe objId fld =
  buildFull tpe idt (Just fld)
  where
    idt        = readIdent rawid :: IdentI m
    (_:rawid:_) = B.split ':' objId

data States = States { from :: [UserStateVal], to :: UserStateVal }
(>>>) :: [UserStateVal] -> UserStateVal -> States
(>>>) f t = States f t

-- | Check current state and maybe create new
checkUserState :: HasPostgres (Handler b m)
               => IdentI Usermeta
               -> Patch Event
               -> Handler b m ()
checkUserState uid ev = do
  hist :: [Patch UserState] <- query
    (fromString (printf
    "SELECT %s FROM \"UserState\" WHERE userId = ? ORDER BY id DESC LIMIT 1"
    (T.unpack $ mkSel (modelInfo :: ModelInfo UserState)))) (Only uid)
  case hist of
    []          -> setNext $ nextState' LoggedOut
    [lastState] -> setNext $ nextState' $ P.get' lastState State.state
  where
    nextState' s = join $ dispatch (P.get' ev E.modelName) (nextState'' s)

    nextState'' :: forall m.Model m => UserStateVal -> m -> Maybe UserStateVal
    nextState'' s _ =
      let mname = modelName (modelInfo :: ModelInfo m)
      in nextState s (P.get' ev E.eventType) mname (join $ P.get ev E.field)

    setNext Nothing = return ()
    setNext (Just s) = (withPG $ \c -> P.create (mkState s) c) >> return ()

    mkState s = P.put State.eventId (P.get' ev E.ident) $
                P.put State.userId uid                  $
                P.put State.state  s                    $
                P.empty

data UserStateEnv = UserStateEnv { lastState :: UserStateVal
                                 , evType    :: EventType
                                 , mdlName   :: Text
                                 , mdlFld    :: Maybe Text
                                 }
type UserStateM   = RWS UserStateEnv [Bool] (Maybe UserStateVal) ()

execUserStateEnv :: UserStateEnv -> UserStateM -> Maybe UserStateVal
execUserStateEnv s c = fst $ execRWS c s Nothing

data Matcher = Fields [(Text, Text)] | Models [Text] | NoModel

-- | Calculate next state
nextState :: UserStateVal
          -- ^ Last user state
          -> EventType
          -> Text
          -- ^ Model name
          -> Maybe Text
          -- ^ Field name
          -> Maybe UserStateVal
nextState lastState evt mname fld =
  execUserStateEnv (UserStateEnv lastState evt mname fld) $ do
    change ([Busy] >>> Ready) $
      on Update $ Fields [field Call.endDate, field Action.result]
    change ([Ready] >>> Busy) $ do
      on Create $ Models [model Call.ident]
      on Update $ Fields [field Action.openTime]
    change ([LoggedOut] >>> Ready)     $ on Login  NoModel
    change (allStates   >>> LoggedOut) $ on Logout NoModel
  where
    field :: forall t n d m1.(Model m1, SingI n)
          => (m1 -> F t n d) -> (Text, Text)
    field f = (modelName (modelInfo :: ModelInfo m1), fieldName f)
    model :: forall t n d m1.(Model m1, SingI n) => (m1 -> F t n d) -> Text
    model _ = modelName (modelInfo :: ModelInfo m1)
    allStates = [minBound .. ]

on :: EventType -> Matcher -> UserStateM
on tpe matcher = do
  UserStateEnv _ evType mname fld <- ask
  let applicable = evType == tpe && isMatch mname fld matcher
  tell [applicable]
  where
    isMatch _     _ NoModel         = True
    isMatch mname _ (Models mnames) = mname `elem` mnames
    isMatch mname fld (Fields fs)   =
      maybe False (\f -> (mname,f) `elem` fs) fld

change :: States -> UserStateM -> UserStateM
change (States from to) onFn = do
  lState <- lastState <$> ask
  ons    <- snd <$> listen onFn
  case lState `elem` from && (any id ons) of
    False -> return ()
    True  -> put (Just to)

-- Utils -----------------------------------------------------------------------

getRealUid :: (HasPostgres (Handler b m), HasAuth b)
           => Handler b m (IdentI Usermeta)
getRealUid = do
  Just u <- withAuth currentUser
  [Only uid] <- query
                [sql| SELECT id from usermetatbl where uid::text = ?|] $
                Only (unUid $ fromJust $ userId $ u)
  return uid

mkActionId :: ByteString -> IdentI Action
mkActionId bs = readIdent bs

addIdent :: forall m.Model m => IdentI m -> Patch Event -> Patch Event
addIdent idt p =
  P.put E.modelName mname $ P.put E.modelId (identVal idt) p
  where
    mname = modelName $ (modelInfo :: ModelInfo m)

setUsr :: IdentI Usermeta -> Patch Event -> Patch Event
setUsr usr p = P.put E.userid usr p