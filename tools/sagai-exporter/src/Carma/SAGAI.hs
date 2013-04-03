{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DoAndIfThenElse #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE TupleSections #-}

{-|

This module contains definitions of how to build every field of
SAGAI entry, all bound together in 'sagaiFullExport' action.

All field combinators (type 'ExportField') use 'push' or 'pushRaw'
to add contents to SAGAI entry.

Exporting a case with services requires first fetching it from
CaRMa, then using is as input data for 'runExport':

> -- Fetch case
> res <- readInstance cp "case" caseNumber
> -- Fetch its services
> servs <- forM (readReferences $ res M.! "services")
>          (\(m, i) -> do
>             inst <- readInstance cp m i
>             return (m, i, inst))
>
> -- Perform export action on this data
> fv <- runExport sagaiFullExport cnt (res, servs) cp dicts encName

Note that all services attached to the case must be supplied to
'runExport', although some of them may not end up being in SAGAI entry.

Final 'ExportState' as returned by 'runExport' contains a fully
formed SAGAI entry, and may also be used to keep @SEP@ counter value
between runs.

-}

module Carma.SAGAI
    ( -- * Running SAGAI export
      sagaiFullExport
    , runExport
    , ExportDicts(..)
    -- * Export results
    , ExportState(..)
    , ExportError(..)
    , ErrorType(..)
    )

where

import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.Error
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State
import Control.Monad.Trans.Writer

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Lazy.Char8 as BSL

import Data.Aeson
import Data.Char
import qualified Data.Dict as D
import Data.Functor
import qualified Data.HashMap.Strict as HM
import Data.List
import qualified Data.Map as M
import Data.Text.Encoding
import Data.Text.ICU.Convert

import Data.Time.Clock
import Data.Time.Format
import System.Locale

import Network.HTTP

import Text.Printf

import Carma.HTTP

import Carma.SAGAI.Base
import Carma.SAGAI.Codes
import Carma.SAGAI.Util


-- | A common interface for both 'CaseExport' and 'ServiceExport'
-- monads used to define fields of an export entry. Most of fields
-- simply use this interface. Several have to be included in the class
-- due to different field content required for case and service
-- entries.
class (Functor m, Monad m, MonadIO m) => ExportMonad m where
    getCase        :: m InstanceData
    getAllServices :: m [Service]
    getCarmaPort   :: m Int
    -- | Fetch a dictionary from export options using a projection.
    getDict        :: (ExportDicts -> D.Dict) -> m D.Dict
    getConverter   :: m Converter
    -- | Return expense type for the case or currently processed
    -- service, depending on monad.
    expenseType    :: m ExpenseType

    -- | Stop export process due to critical error.
    exportError    :: ErrorType -> m a

    getState       :: m ExportState
    putState       :: ExportState -> m ()

    -- Fields for which export rules differ between case and services.
    panneField     :: m Int
    defField       :: m Int
    somField       :: m Int
    comm3Field     :: m Int


instance ExportMonad CaseExport where
    getCase = lift $ asks $ fst . fst

    getAllServices = lift $ asks $ snd . fst

    getCarmaPort = lift $ asks $ carmaPort . snd

    getDict proj = lift $ asks $ proj . dicts . snd

    getConverter = lift $ asks $ utfConv . snd

    exportError e = lift $ lift $ lift $ throwError $ CaseError e

    getState = get

    putState = put

    expenseType = return Dossier

    panneField = cnst "0"

    defField = push =<< codeField defCode

    somField = push =<< padRight 10 '0' <$> codeField (formatCost . cost)

    comm3Field = do
      servs <- getNonFalseServices
      pushComment $ case servs of
        [] -> BS.empty
        ((_, _, d):_) -> dataField0 "orderNumber" d


-- | Add an entry to export log.
exportLog :: String -> CaseExport ()
exportLog s = lift $ lift $ tell [s]


instance ExportMonad ServiceExport where
    getCase = lift $ lift $ asks $ fst . fst

    getAllServices = lift $ lift $ asks $ snd . fst

    getCarmaPort = lift $ lift $ asks $ carmaPort . snd

    getDict proj = lift $ lift $ asks $ proj . dicts . snd

    getConverter = lift $ lift $ asks $ utfConv . snd

    exportError e = do
      (m, i, _) <- getService
      lift $ lift $ lift $ lift $ throwError $ ServiceError m i e

    expenseType = asks snd

    getState = lift $ get

    putState = lift . put

    panneField = cnst "1"

    defField = do
      et <- expenseType
      push =<< case et of
        -- Special handling for rental service DEF code.
        Rent ->
            do
              (_, _, d) <- getService
              return $ BS.append "G" $
                     padRight 2 '0' $ B8.pack $ show $ capRentDays d
        _ -> codeField defCode

    somField = do
        et <- expenseType
        push =<< padRight 10 '0' <$> case et of
          -- Special handling for rental service cost calculation.
          Rent ->
              do
                program <- caseField "program"
                (_, _, d) <- getService
                carClass <- dataField1 "carClass" d
                let dailyCost =
                        case M.lookup (program, carClass) rentCosts of
                          Just dc -> dc
                          -- Zero cost for unknown car classes.
                          Nothing -> 0
                return $ formatCost (dailyCost * (fromIntegral $ capRentDays d))
          _ -> codeField (formatCost . cost)

    comm3Field = do
        (mn, _, d) <- getService
        let oNum = dataField0 "orderNumber" d
        fields <-
            case mn of
              "tech" ->
                  do
                    tType <- labelOfValue
                             (dataField0 "techType" d)
                             (getDict techTypes)
                    return [oNum, tType]
              -- More fields are requred for towage/rental service
              "rent" ->
                  do
                    carCl <- labelOfValue
                             (dataField0 "carClass" d)
                             (getDict carClasses)
                    return [carCl, oNum]
              "towage" ->
                  do
                    -- Try to fetch contractor code (not to be
                    -- confused with partner id) for selected
                    -- contractor
                    let partnerField = "towDealer_partnerId"
                        sPid = dataField0 partnerField d
                    cp <- getCarmaPort
                    pCode <- case (BS.null sPid, read1Reference sPid) of
                      -- If no partnerId specified, do not add partner
                      -- code to extra information to comm3 field.
                      (True, _) ->
                          return "#?"
                      (False, Nothing) ->
                          exportError (UnreadableContractorId sPid)
                      (False, Just (_, pid)) ->
                          dataField0 "code" <$>
                          (liftIO $ readInstance cp "partner" pid)
                    return [oNum, pCode]
              _ -> error "Never happens"
        pushComment $ BS.intercalate " " fields


-- | Recode a string from UTF-8 to the output encoding specified in
-- export options.
recode :: ExportMonad m => BS.ByteString -> m BS.ByteString
recode bs = do
  c <- getConverter
  return $ fromUnicode c $ decodeUtf8 bs


-- | Recode and add new contents to SAGAI entry, return count of bytes
-- added.
push :: ExportMonad m => BS.ByteString -> m Int
push bs = recode bs >>= pushRaw


-- | Add new contents to SAGAI entry as is without recoding, return
-- count of bytes added.
--
-- Used when an input ByteString needs to be recoded and then
-- processed prior to pushing.
pushRaw :: ExportMonad m => BS.ByteString -> m Int
pushRaw bs = do
  s <- getState
  putState s{content = BS.append (content s) bs}
  return $ BS.length bs


-- | Return the service being processed.
getService :: ServiceExport Service
getService = asks fst


-- | Calculate expense type for a service. Used to initialize
-- 'ServiceExport' state when processing nested services inside
-- 'CaseExport' monad (so that service expense type is computed only
-- once).
serviceExpenseType :: Service -> CaseExport ExpenseType
serviceExpenseType s@(mn, _, d) = do
  case (notFalseService s, mn) of
    (False, _) -> return FalseCall
    (_, "consultation") -> return PhoneServ
    (_, "towage") ->
        do
          cid <- caseField1 "id"
          cp <- getCarmaPort
          liftIO $ do
                -- Check if this towage is a repeated towage using
                -- CaRMa HTTP method
                rs <- simpleHTTP $ getRequest $
                      methodURI cp $ "repTowages/" ++ (B8.unpack cid)
                rsb <- getResponseBody rs
                case (decode' $ BSL.pack rsb :: Maybe [Int]) of
                  Just [] -> return Towage
                  Just _  -> return RepTowage
                  -- TODO It's actually an error
                  Nothing -> return Towage
    (_, "rent") -> return Rent
    (_, "tech") -> do
            techType <- dataField1 "techType" d
            case techType of
              "charge"    -> return Charge
              "condition" -> return Condition
              "starter"   -> return Starter
              _           -> exportError $ UnknownTechType techType
    _        -> exportError $ UnknownService mn


-- | Get a value of a field in the case entry being exported.
-- Terminate export if field is not found.
dataField :: ExportMonad m => FieldName -> InstanceData -> m FieldValue
dataField fn d =
  case HM.lookup fn d of
    Just fv -> return fv
    Nothing -> exportError $ NoField fn


-- | A version of 'dataField' which returns empty string if key is not
-- present in instance data (like 'M.findWithDefault')
dataField0 :: FieldName -> InstanceData -> FieldValue
dataField0 fn d = HM.lookupDefault BS.empty fn d


-- | A version of 'dataField' which requires non-empty field value and
-- terminates with 'EmptyField' error otherwise.
dataField1 :: ExportMonad m => FieldName -> InstanceData -> m FieldValue
dataField1 fn d = do
  fv <- dataField fn d
  case BS.null fv of
    False -> return fv
    True -> exportError $ EmptyField fn


caseField :: ExportMonad m => FieldName -> m FieldValue
caseField fn = dataField fn =<< getCase


caseField0 :: ExportMonad m => FieldName -> m FieldValue
caseField0 fn = dataField0 fn <$> getCase


caseField1 :: ExportMonad m => FieldName -> m FieldValue
caseField1 fn = dataField1 fn =<< getCase


-- | Return all exportable non-false services from services attached
-- to the case.
getNonFalseServices :: ExportMonad m => m [Service]
getNonFalseServices = do
  servs <- getAllServices
  return $ filter notFalseService servs


-- | True if a service is exportable and was not a false call
-- (@falseCall@ field is @none@ or @bill@).
notFalseService :: Service -> Bool
notFalseService (_, _, d) = elem (dataField0 "falseCall" d) ["none", "bill"]


-- | True if service should be exported to SAGAI.
exportable :: Service -> Bool
exportable s@(mn, _, d) = notFalseService s && typeOk
    where typeOk =
              case mn of
                "consultation" -> True
                "towage"       -> True
                "rent"         -> True
                "tech"         ->
                    elem (dataField0 "techType" d)
                             ["charge", "condition", "starter"]
                _        -> False


-- | Check if @callDate@ field of the case contains a date between dates
-- stored in two other case fields.
callDateWithin :: ExportMonad m =>
                  FieldName
               -- ^ Name of field with first date. @callDate@ must be
               -- not less that this.
               -> FieldName
               -- ^ @callDate@ must not exceed this.
               -> m Bool
callDateWithin f1 f2 = do
  ts1 <- caseField0 f1
  ts  <- caseField1 "callDate"
  ts2 <- caseField0 f2
  return $ case (parseTimestamp ts1,
                 parseTimestamp ts,
                 parseTimestamp ts2) of
    (Just t1, Just t, Just t2) -> t1 <= t && t < t2
    _ -> False


-- | Check if servicing contract is in effect.
onService :: ExportMonad m => m Bool
onService = do
  d <- callDateWithin "car_warrantyStart" "car_warrantyEnd"
  ct <- caseField0 "car_contractType"
  return $ d && (not $ elem ct ["warranty", ""])


-- | An action which pushes new content to contents of the SAGAI entry
-- and returns count of bytes added.
type ExportField = ExportMonad m => m Int


cnst :: ExportMonad m => BS.ByteString -> m Int
cnst = push


newline :: B8.ByteString
newline = "\n"


space :: Char
space = ' '


rowBreak :: ExportField
rowBreak = push newline


pdvField :: ExportField
pdvField = do
  fv <- caseField1 "program"
  case fv of
    "peugeot" -> push "RUMC01R01"
    "citroen" -> push "FRRM01R01"
    _         -> exportError $ UnknownProgram fv


dtField :: ExportField
dtField = push =<< padRight 8 '0' <$> caseField1 "id"


vinField :: ExportField
vinField = do
  bs <- caseField1 "car_vin"
  if (B8.length bs) == 17
  then push $ B8.pack $ map toUpper $ B8.unpack bs
  else exportError $ BadVin bs


dateFormat :: String
dateFormat = "%d%m%y"


-- | Convert timestamp to DDMMYY format.
timestampToDate :: BS.ByteString -> ExportField
timestampToDate input =
    case parseTimestamp input of
      Just time ->
          push $ B8.pack $ formatTime defaultTimeLocale dateFormat time
      Nothing -> exportError $ BadTime input


-- | Search for an entry in 'codesData' using program name of the case
-- and expense type, project the result to output.
codeField :: ExportMonad m =>
             (CodeRow -> BS.ByteString)
          -- ^ Projection function used to produce output from the
          -- matching 'codesData' entry.
          -> m BS.ByteString
codeField proj = do
  program <- caseField "program"
  key <- expenseType
  case M.lookup (program, key) codesData of
    Nothing -> exportError $ UnknownProgram program
    Just c -> return $ proj c


-- | Format 231.42 as "23142". Fractional part is truncated to 2
-- digits.
formatCost :: Double -> BS.ByteString
formatCost gc = BS.concat $ B8.split '.' $ B8.pack $ printf "%.2f" gc


impField :: ExportField
impField = do
  onS <- onService
  let proj = if onS
             then serviceImpCode
             else impCode
  push =<< codeField proj


causeField :: ExportField
causeField = push =<< padRight 15 '0' <$> codeField causeCode


-- | Extract properly capped amount of days from "providedFor" field
-- of instance data (used for rental service entries).
capRentDays :: InstanceData -> Int
capRentDays d = do
  -- Cap days to be within [0..4]
  case B8.readInt $ dataField0 "providedFor" d of
    Just (n, _) ->
        if n > 4
        then 4
        else if n < 0
             then 0
             else n
    Nothing -> 0


-- | Sequential counter.
composField :: ExportField
composField = do
  s <- getState
  let newCounter' = counter s + 1
      -- Wrap counter when it reaches 999999
      newCounter  = if newCounter' > 999999 then 0 else newCounter'
  putState $ s{counter = newCounter}
  push $ padRight 6 '0' $ B8.pack $ show $ counter s


ddgField :: ExportField
ddgField = push =<< caseField1 "car_warrantyStart"


ddrField :: ExportField
ddrField = timestampToDate =<< caseField1 "callDate"


ddcField :: ExportField
ddcField = do
  ctime <- liftIO $ getCurrentTime
  push $ B8.pack $ formatTime defaultTimeLocale dateFormat ctime


kmField :: ExportField
kmField = push =<< padRight 6 '0' <$> caseField "car_mileage"


spaces :: ExportMonad m => Int -> m Int
spaces n = push $ B8.replicate n space


accordField :: ExportField
accordField = push =<< padRight 6 space <$> caseField0 "accord"


nhmoField :: ExportField
nhmoField = spaces 5


somprField :: ExportField
somprField = spaces 10


fillerField :: ExportField
fillerField = spaces 5


-- | Pad input up to 72 characters with spaces or truncate it to be no
-- longer than 72 chars. Remove all newlines. Truncation and padding
-- is done wrt to bytestring length when encoded using output
-- character set, not UTF-8. Processed string is then added to entry
-- contents. Return count of bytes added.
pushComment :: ExportMonad m =>
              BS.ByteString
           -- ^ Input bytestring in UTF-8.
           -> m Int
pushComment input =
    do
      inBS <- recode input
      -- Assume space is single-byte in any of used encodings
      space' <- B8.head <$> (recode $ B8.singleton space)
      let outBS = B8.map (\c -> if B8.elem c newline then space else c) $
                  BS.take 72 $
                  padLeft 72 space' $
                  inBS
      pushRaw outBS


-- | Map a label of a dictionary to its value, terminate export with
-- 'UnknownDictValue' error otherwise.
labelOfValue :: ExportMonad m =>
                BS.ByteString
             -> (m D.Dict)
             -- ^ A projection used to fetch dictionary from export
             -- monad state.
             -> m BS.ByteString
labelOfValue val dict = do
  d <- dict
  case D.labelOfValue val d of
    Just label -> return label
    Nothing -> exportError $ UnknownDictValue val


-- | Try to map a label of a dictionary to its value, fall back to
-- label if its value is not found.
tryLabelOfValue :: ExportMonad m =>
                   BS.ByteString
                -> (m D.Dict)
                -> m BS.ByteString
tryLabelOfValue val dict = do
  d <- dict
  return $ case D.labelOfValue val d of
    Just label -> label
    Nothing -> val


comm1Field :: ExportField
comm1Field = do
  val <- caseField1 "comment"
  pushComment =<< tryLabelOfValue val (getDict wazzup)


comm2Field :: ExportField
comm2Field = pushComment =<< caseField0 "dealerCause"


-- | A list of field combinators (typed as ExportField) to form a part
-- of export entry.
type ExportPart = ExportMonad m => [m Int]


-- | Basic part for any line.
basicPart :: ExportPart
basicPart =
    [ cnst "FGDC"
    , cnst "DM1"
    , pdvField
    , dtField
    , vinField
    , impField
    , causeField
    ]


-- | Common part for all non-comment lines (prior to @PANNE@ field).
refundPart :: ExportPart
refundPart =
    [ cnst "1"
    , composField
    , cnst " "
    , ddgField
    , ddrField
    , kmField
    , accordField
    , panneField
    , nhmoField
    , somField
    , somprField
    , defField
    , cnst "C"
    , ddcField
    , fillerField
    , rowBreak
    ]


-- | First (ENR=3) comment part.
comm1Part :: ExportPart
comm1Part =
    [ cnst "3"
    , comm1Field
    , rowBreak
    ]


-- | Second (ENR=4) comment part.
comm2Part :: ExportPart
comm2Part =
    [ cnst "4"
    , comm2Field
    , rowBreak
    ]


-- | Third (ENR=6) comment part.
comm3Part :: ExportPart
comm3Part =
    [ cnst "6"
    , comm3Field
    , rowBreak
    ]


-- | Defines all lines and fields in an entry for a case or a service.
entrySpec :: ExportPart
entrySpec = concat $
    [ basicPart
    , refundPart
    , basicPart
    , comm1Part
    , basicPart
    , comm2Part
    , basicPart
    , comm3Part
    ]


-- | Form an entry for the case or the service, depending on the
-- particular monad. Return total count of bytes added.
sagaiExport :: ExportMonad m => m Int
sagaiExport = sum <$> mapM id entrySpec


-- | Format service data as @towage:312@ (model name and id).
formatService :: Service -> String
formatService (mn, i, _) =  mn ++ ":" ++ show i


formatServiceList :: [Service] -> String
formatServiceList ss = "[" ++ (intercalate "," $ map formatService ss) ++ "]"


-- | Initialize 'ServiceExport' monad and run 'sagaiExport' in it for
-- a service.
runServiceExport :: Service -> CaseExport Int
runServiceExport s = do
  exportLog $ "Now exporting " ++ formatService s
  et <- serviceExpenseType s
  exportLog $ "Expense type of service is " ++ show et
  runReaderT sagaiExport (s, et)


-- | Form a full entry for the case and its services (only those which
-- satisfy requirements defined by the spec). Return total byte count
-- in the entry.
sagaiFullExport :: CaseExport Int
sagaiFullExport = do
  et <- expenseType
  exportLog $ "Expense type is " ++ show et
  caseOut <- sagaiExport

  allServs <- getAllServices
  let servs = filter exportable allServs
  exportLog $ "Case services: " ++ formatServiceList allServs ++
              ", exporting: " ++ formatServiceList servs
  servsOut <- sum <$> mapM runServiceExport servs

  return $ caseOut + servsOut
