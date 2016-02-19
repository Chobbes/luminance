-----------------------------------------------------------------------------
-- |
-- Copyright   : (C) 2015, 2016 Dimitri Sabadie
-- License     : BSD3
--
-- Maintainer  : Dimitri Sabadie <dimitri.sabadie@gmail.com>
-- Stability   : experimental
-- Portability : portable
--
-- = What is luminance?
--
-- __luminance__ is a small yet powerful graphics API. It was designed so that people can quickly
-- get their feet wet and start having fun with graphics in /Haskell/. The main idea is to unleash
-- the graphical and visual properties of /GPUs/ in a stateless and type-safe way.
--
-- This library doesn’t expose any architectural patterns or designs. It’s up to you to design your
-- program as you want and following your own plans. Because it’s a graphics and rendering API, you
-- won’t find several common things you find in animations, games or simulations. If you need those
-- you’ll have to look for dedicated libraries instead.
--
-- One of the most important thing you have to keep in mind is the fact that luminance won’t
-- provide you with anything else than working with the /GPU/. That is, it won’t even provide
-- functions to open windows. That’s actually a good thing, because then you’ll be able to use it
-- with /any kind of windowing and system library you want to/!
--
-- The drawback is about safety. If you screw up setting up the OpenGL context, there’s no way
-- luminance will work. If users feel the need, a few dedicated packages will be uploaded, like
-- __luminance-glfw__ to add "GLFW-b" support for instance.
--
-- = Getting started
--
-- == Setting up the window and OpenGL context
--
-- The first thing to do is to create a window. Here’s a typical "GLFW-b" snippet to create such
-- a window.
--
-- @
--   initialized <- init
--   when initialized $ do
-- @
--
-- In the first place, we initialize the "GLFW-b" library and make sure everything ran smoothly.
--
-- @
--     windowHint (WindowHint'Resizable False)
--     windowHint (WindowHint'ContextVersionMajor 4)
--     windowHint (WindowHint'ContextVersionMinor 5)
--     windowHint (WindowHint'OpenGLForwardCompat False)
--     windowHint (WindowHint'OpenGLProfile OpenGLProfile'Core)
--     window <- createWindow 800 600 "luminance application" Nothing Nothing
-- @
--
-- That part just setup the window’s OpenGL hints so that we create a compatible context for
-- luminance. luminance will work with __OpenGL 4.5__ only, don’t even try to make it work with a
-- lower implementation. We also disable the /forward compatibility/ because we don’t need it and
-- ask to stick to a /core/ profile.
--
-- @
--     case window of
--       Just window' -> do
--         makeContextCurrent window
--         swapInterval 1
--         -- we’re good to go!
--         destroyWindow window'
--       Nothing -> hPutStrLn stderr "unable to create window; please check your hardware support OpenGL4.5"
-- @
--
-- We then test 'window'. If we have successfully opened the window, we go on by making the OpenGL
-- context of the window the current one for the current thread, set the swap interval (that’s not
-- important for the purpose of that tutorial) and we’re good to go. Otherwise, we just display an
-- error message and quit.
--
-- @
--   terminate
-- @
--
-- We finally close the "GLFW-b" context to cleanup everything.
--
-- == Preparing the environment for luminance
--
-- A lot of the functions you’ll use work in special types. For instance, a lot of @create*@
-- functions will require @('MonadIO' m,'MonadResource' m,'MonadError' e m) => m@ or so. For that
-- reason, we’ll be using a type of our own and will unwrap it so that we end up in 'IO' in the end.
--
-- Here’s the type:
--
-- @
--   type App = ExceptT AppError (ResourceT IO)
--
--   newtype AppError = AppError String deriving (Eq,Show)
-- @
--
-- And we’ll unwrap from our type to 'IO' with:
--
-- @
--   runResourceT . runExcepT
-- @
--
-- = Getting something to the screen
--
-- == About the screen
--
-- luminance generalizes OpenGL concepts so that they’re made safer. In order to render something
-- onto the screen, you have to understand what the screen truly is. It’s actually… a back buffer –
-- assuming we have double buffering enabled, which the case with "GLFW-b" by default. So rendering
-- to the screen is the same thing than rendering to the back buffer and ask "GLFW-b" to swap the
-- back buffer with the front buffer.
--
-- And guess what. luminance wraps the back buffer into a 'Framebuffer' object. You can access it
-- through 'defaultFramebuffer'. That value will always represent the back buffer.
--
-- == About batched rendering
--
-- In most graphics frameworks, rendering is the act of taking an object and getting it rendered.
-- luminance follows a different path. Because of real world needs and, well, real applications, you
-- cannot do that in luminance. Because, what serious application will render only __one__ object?
-- None. If so, then it’s an exception. We shouldn’t design our libraries and interface for the
-- exceptions. We should build them for the most used case, which is, having a lot of objects in a
-- scene.
--
-- That’s why luminance exposes the concept of /batched rendering/. The idea is that you have to
-- gather you objects in /batches/ and render them all at once. That enables a correct sharing of
-- resources – for instance, framebuffers or textures – and is very straight-forward to reason
-- about.
--
-- luminance has several types of batches, each for the type of shared information. You can – up to
-- now – shared two information between the rendered objects:
--
-- * /framebuffer/: that means you can create a 'FBBatch' that will gather several values under the
--   same 'Framebuffer';
-- * or /shaders/: that means you can create a 'SPBatch' that will gather several values under the
--   same shader 'Program'.
--
-- The idea is that the 'SPBatch'es are stored in 'FBBatch'es. That creates a structure similar to
-- an AST luminance knows how to dispatch to the GPU.
--
-- == About shader stages
--
-- luminance supports five kinds of shader stage:
--
-- * /tessellation evaluation shader/
-- * /tessellation control shader/
-- * /vertex shader/
-- * /geometry shader/
-- * /fragment shader/
--
-- Additionnaly, you can create /compute shaders/ but they’re not usable up to now.
--
-- When creating a new shader, you have to pass a 'String' representing the source code. This will
-- change in the end. An EDSL is planned to make things easier and safer, but in the waiting, you
-- are stuck with 'String', I’m sorry.
--
-- You have to write /GLSL450/-conformant code.
--
-- == About uniforms
--
-- Shaders are customized through uniforms. Those are very handy and very simple to use in
-- luminance. You have the possibility to get them when creating shader 'Program's. The
-- 'createProgram' function expects two parameters: a list of shader 'Stage's and a uniform
-- interface builder function. That function takes another function as parameter you can use to
-- retrieve a uniform 'U' by passing 'Either' a 'String' for the name of the uniform or a 'Natural'
-- for its explicit semantic. Be careful when using explicit semantics though; they’re not tested.
--
-- Here’s an exemple of such a use:
--
-- @
--   (program,uniformInterface) \<- 'createProgram' shaderStages $ \\uni -\> do
--     resolutionU <- uni $ 'Left' "resolution"
--     timeU <- uni $ 'Left' "time"
--     'pure' $ 'divided' resolutionU timeU
-- @
--
-- In that example, @uniformInterface@ has type @U ((Float,Float),Float)@, @(Float,Float@ being the
-- type of the @resolutionU@ part and @Float@ being the part for @timeU@. 'divided' is a method of
-- 'Divisible' – the typeclass of divisible contravariant functors – which is defined in the
-- "contravariant" package.
--
-- If you don’t need uniform interface, you can build a dummy object, like @()@, or simply use the
-- appropriate 'createProgram_' function.
--
-- == About 'RenderCmd' and 'Geometry'
--
-- 'RenderCmd' is a very simple type yet powerful one. It’s a way to add stateless support to
-- OpenGL render commands – draw commands, actually. It gathers several information you can set
-- when performing a draw command. A 'RenderCmd' can hold any type of object, but the most useful
-- version of it holds 'Geometry'.
--
-- A 'Geometry' is a /GPU/ version of a mesh. It’s composed of /vertices/, /indices/ and a primitive
-- mode used to know how to link vertices between each others. Sometimes, 'Geometry' doesn’t have
-- /indices/. That’s called __direct geometry__, because the /vertices/ are supposed to be directly
-- used when creating primitives. If you use /indices/, then you have an __indexed geometry__ and
-- the /vertices/ can linked by looking at the /indices/ you’ve fed in.
--
-- A 'Geometry' is created with the 'createGeometry' function and a 'RenderCmd' is created with
-- 'renderCmd'. You’re supposed to create a 'Geometry' once – while loading your resources for
-- example – and the 'RenderCmd' can be created on the fly – it doesn’t require 'IO'.
--
-- == Putting all together
--
-- Let’s draw a triangle on the screen! First, we need the vertices!
--
-- @
--   vertices :: ['V' 2 'Float']
--   vertices =
--     [
--       'vec2' (-0.5) (-0.5)
--     , 'vec2' 0 0.5
--     , 'vec2' 0.5 (-0.5)
--     ]
-- @
--
-- @'V' 2@ is a cool type used to represent /vertex attributes/. You’ll need `DataKinds` to be able
-- to use it.
--
-- Then, we don’t need /indices/ because we can directly issue a draw. Let’s then have the /GPU/
-- version of those vertices:
--
-- @
--   triangle <- 'createGeometry' vertices 'Nothing' 'Triangle'
-- @
--
-- Then, we need a shader! Let’s write the vertex shader first:
--
-- @
--   in vec2 co;
--   out vec4 vertexColor;
--    
--   vec4 color[3] = vec4[](
--       vec4(1., 0., 0., 1.)
--     , vec4(0., 1., 0., 1.)
--     , vec4(0., 0., 1., 1.)
--     );
--    
--   void main() {
--     gl_Position = vec4(co, 0., 1.);
--     vertexColor = color[gl_VertexID];
--   }
-- @
--
-- Nothing fancy, except that we pass @vertexColor@ to the next stage so that we can blend between
-- vertices.
--
-- Now, a fragment shader:
--
-- @
--   in vec4 vertexColor;
--   out vec4 frag;
--    
--   void main() {
--     frag = vertexColor;
--   }
-- @
--
-- Now, let’s create the shader 'Stage's and the shader 'Program':
--
-- @
--   program \<- 'sequenceA' ['createVertexShader' vsSrc,'createFragmentShader' fsSrc] \>\>= createProgram_
-- @
--
-- Once again, that’s pretty straight-forward.
--
-- Finally, we need the batches. We’ll need one 'FBBatch' and one 'SPBatch'.
--
-- @
--   let spb = 'shaderProgramBatch_' program ['stdRenderCmd_' triangle]
--       fbb = 'framebufferBatch' 'defaultFramebuffer' ['anySPBatch' spb]
-- @
--
-- Ok, so let’s explain all of this. 'shaderProgramBatch_' is a shorter version of
-- 'shaderProgramBatch' you can use to build 'SPBatch'. The extra underscore means you don’t want no
-- uniform interface. We pass our @program@ and a singleton list containing a 'RenderCmd' we create
-- with the 'stdRenderCmd_'. Once again, the extra underscore stands for no uniform interface. We
-- then just pass our @triangle@. Notice that both 'stdRenderCmd' and 'stdRenderCmd_' disable color
-- blending and enable depth test so that you don’t have to pass those information around.
--
-- Then, we create the 'FBBatch'. That is done via the 'framebufferBatch' function. It takes the
-- 'Framebuffer' to render into – in our case, the 'defaultFramebuffer', which is the /back buffer/.
-- We also pass a singleton list of the universally quantified 'SPBatch' with the 'anySPBatch'
-- function.
--
-- We just need to issue a command to the /GPU/ to render our triangle. That is done with a
-- constrained type, 'Cmd'.
--
-- @
--   void . runCmd $ draw fbb
-- @
--
-- We don’t need the result of 'runCmd' in our case so we discard it with 'void'. 'runCmd' runs in
-- 'MonadIO'.
--
-- We just need to swap the buffers with @swapBuffers window@ – see "GLFW-b" for further details –
-- and we’re good!
--
-- = Dealing with 'Texture2D'
--
-- Up to now, luminance only supports 2D-textures. More texture types will be added as luminance
-- gets mature. The interface might change a lot, because it might be very inefficient, especially
-- when converting from containers to others.
-----------------------------------------------------------------------

module Graphics.Luminance (
    module Control.Some
  , module Graphics.Luminance.Blending
  , module Graphics.Luminance.Buffer
  , module Graphics.Luminance.Cmd
  , module Graphics.Luminance.Core.Tuple
  , module Graphics.Luminance.Framebuffer
  , module Graphics.Luminance.Geometry
  , module Graphics.Luminance.Pixel
  , module Graphics.Luminance.Query
  , module Graphics.Luminance.Region
  , module Graphics.Luminance.RenderCmd
  , module Graphics.Luminance.RW
  , module Graphics.Luminance.Shader
  , module Graphics.Luminance.Texture
  , module Graphics.Luminance.Vertex
  ) where

import Control.Some
import Graphics.Luminance.Blending
import Graphics.Luminance.Buffer
import Graphics.Luminance.Cmd
import Graphics.Luminance.Core.Tuple
import Graphics.Luminance.Framebuffer
import Graphics.Luminance.Geometry
import Graphics.Luminance.Pixel
import Graphics.Luminance.Query
import Graphics.Luminance.Region
import Graphics.Luminance.RenderCmd
import Graphics.Luminance.RW
import Graphics.Luminance.Shader
import Graphics.Luminance.Texture
import Graphics.Luminance.Vertex
