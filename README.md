# Experimental integration of ffmpeg into PPSSPP as a bundled module

This is a WIP experimental integration of ffmpeg into PPSSPP as a bundled module.

To test this, extract a PPSSPP source tarball (or git pull). Create two new folders instead of PPSSPP's ext/ folder:

ffmpeg
ffmpeg-build

Copy the contents of [ppsspp-ffmpeg](https://github.com/hrydgard/ppsspp-ffmpeg) into the newly created ext/ffmpeg folder. You do not need to include the prebuilt binaries for various systems and architectures. Alternatively, copy the contents of a source tarball for ffmpeg-3.0.2.

The contents of this repository, minus the two patch- files, should go into the ext/ffmpeg-build folder. 

PPSSPP's CMakeLists.txt and ext/CMakeLists.txt will also need to be patched using the two patches in this repository.

Then, PPSSPP can be built normally--simply set the patched-in BUILD_BUNDLED_FFMPEG cmake option on. PPSSPP will then attempt to build ffmpeg as a regular bundled module rather than importing it as a third-party library.

This bundled ffmpeg module does NOT utilize Assembly or architecture-specific optimizations. For the limited use case of ffmpeg in PPSSPP, playback of generally small H.264 videos, any gains from those optimizations are supposedly minimal yet greatly increase the complexity of porting ffmpeg to cmake (and fragility of the build itself).
