-----------------------------------------------------------------------------
-- |
-- Copyright   : (C) 2015 Dimitri Sabadie
-- License     : BSD3
--
-- Maintainer  : Dimitri Sabadie <dimitri.sabadie@gmail.com>
-- Stability   : experimental
-- Portability : portable
-----------------------------------------------------------------------------

module Graphics.Luminance.Geometry where

import Control.Monad.IO.Class ( MonadIO(..) )
import Control.Monad.Trans.Resource ( MonadResource, register )
import Data.Proxy ( Proxy(..) )
import Data.Word ( Word32 )
import Foreign.Marshal.Alloc ( alloca )
import Foreign.Marshal.Array ( peekArray, pokeArray )
import Foreign.Marshal.Utils ( with )
import Foreign.Ptr ( Ptr, castPtr )
import Foreign.Storable ( Storable(..) )
import GHC.TypeLits ( KnownNat, Nat, natVal )
import Graphics.GL
import Graphics.Luminance.Buffer
import Graphics.Luminance.GPU
import Graphics.Luminance.RW ( W )
import Graphics.Luminance.Tuple

vertexBindingIndex :: GLuint
vertexBindingIndex = 0

data VertexArray = VertexArray {
    vertexArrayID :: GLuint
  , vertexArrayMode :: GLenum
  , vertexArrayCount :: GLsizei
  } deriving (Eq,Show)
  
data Geometry
  = DirectGeometry VertexArray
  | IndexedGeometry VertexArray
    deriving (Eq,Show)

data GeometryMode
  = Point
  | Line
  | Triangle
    deriving (Eq,Show)

fromGeometryMode :: GeometryMode -> GLenum
fromGeometryMode m = case m of
  Point    -> GL_POINTS
  Line     -> GL_LINES
  Triangle -> GL_TRIANGLES
  
createGeometry :: forall f m v. (Foldable f,MonadIO m,MonadResource m,Storable v,Vertex v)
               => f v
               -> Maybe (f Word32)
               -> GeometryMode
               -> m Geometry
createGeometry vertices indices mode = do
    -- create the vertex array object (OpenGL-side)
    vid <- liftIO . alloca $ \p -> do
      glCreateVertexArrays 1 p
      peek p
    _ <- register . with vid $ glDeleteVertexArrays 1
    -- vertex buffer
    (vreg :: Region W v,vbo) <- createBuffer_ $ newRegion (fromIntegral vertNb)
    writeWhole vreg vertices
    liftIO $ glVertexArrayVertexBuffer vid vertexBindingIndex (bufferID vbo) 0 (fromIntegral $ sizeOf (undefined :: v))
    setFormatV vid 0 (Proxy :: Proxy v)
    -- element buffer, if required
    case indices of
      Just indices' -> do
        (ireg :: Region W Word32,ibo) <- createBuffer_ $ newRegion (fromIntegral ixNb)
        writeWhole ireg indices'
        glVertexArrayElementBuffer vid (bufferID ibo)
        pure . IndexedGeometry $ VertexArray vid mode' (fromIntegral ixNb)
      Nothing -> pure . DirectGeometry $ VertexArray vid mode' (fromIntegral vertNb)
  where
    vertNb = length vertices
    ixNb   = length indices
    mode'  = fromGeometryMode mode

-- TODO: we should move that into Graphics.Luminance.Vertex, I guess.
data V :: Nat -> * -> * where
  V1 :: !a -> V 1 a
  V2 :: !a -> !a -> V 2 a
  V3 :: !a -> !a -> !a -> V 3 a
  V4 :: !a -> !a -> !a -> !a -> V 4 a

instance (Storable a) => Storable (V 1 a) where
  sizeOf _ = sizeOf (undefined :: a)
  alignment _ = alignment (undefined :: a)
  peek p = fmap V1 $ peek (castPtr p :: Ptr a)
  poke p (V1 x) = poke (castPtr p) x

instance (Storable a) => Storable (V 2 a) where
  sizeOf _ = 2 * sizeOf (undefined :: a)
  alignment _ = alignment (undefined :: a)
  peek p = do
    [x,y] <- peekArray 2 (castPtr p :: Ptr a)
    pure $ V2 x y
  poke p (V2 x y) = pokeArray (castPtr p) [x,y]

instance (Storable a) => Storable (V 3 a) where
  sizeOf _ = 3 * sizeOf (undefined :: a)
  alignment _ = alignment (undefined :: a)
  peek p = do
    [x,y,z] <- peekArray 3 (castPtr p :: Ptr a)
    pure $ V3 x y z
  poke p (V3 x y z) = pokeArray (castPtr p) [x,y,z]

instance (Storable a) => Storable (V 4 a) where
  sizeOf _ = 4 * sizeOf (undefined :: a)
  alignment _ = alignment (undefined :: a)
  peek p = do
    [x,y,z,w] <- peekArray 4 (castPtr p :: Ptr a)
    pure $ V4 x y z w
  poke p (V4 x y z w) = pokeArray (castPtr p) [x,y,z,w]

class Vertex v where
  setFormatV :: (MonadIO m) => GLuint -> GLuint -> Proxy v -> m ()

instance (GPU a,KnownNat n,Storable a) => Vertex (V n a) where
  setFormatV vid index _ = do
    glVertexArrayAttribFormat vid index (fromIntegral $ natVal (Proxy :: Proxy n)) (glType (Proxy :: Proxy a)) GL_FALSE 0
    glVertexArrayAttribBinding vid index vertexBindingIndex
    glEnableVertexArrayAttrib vid index

instance (Vertex a,Vertex b) => Vertex (a :. b) where
  setFormatV vid index _ = do
    setFormatV vid index (Proxy :: Proxy a)
    setFormatV vid index (Proxy :: Proxy b)