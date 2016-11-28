module Carma.Model.DiagSlide where

import Data.Aeson as Aeson
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Typeable

import Data.Model
import Data.Model.View

import Carma.Model.Types()
import Carma.Model.PgTypes()


data DiagSlide = DiagSlide
  { ident     :: PK Int DiagSlide ""
  , ctime     :: F UTCTime "ctime" "Дата создания"
  , header    :: F Text "header" "Вопрос"
  , body      :: F Text "body" "Описание"
  , resources :: F Aeson.Value "resources" "Картинки"
  , answers   :: F Aeson.Value "answers" "Ответы"
  , isRoot    :: F Bool "isRoot" "Начало опроса"
  } deriving Typeable



instance Model DiagSlide where
  type TableName DiagSlide = "DiagSlide"
  modelInfo = mkModelInfo DiagSlide ident
  modelView = \case
    "" -> Just defaultView
    _  -> Nothing

