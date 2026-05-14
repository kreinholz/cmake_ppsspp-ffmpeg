# Experimental integration of ffmpeg into PPSSPP as a bundled module

This is a WIP experimental integration of ffmpeg into PPSSPP as a bundled module. To test it, copy the contents of this repository (minus the two patch files) to a new folder inside an extracted PPSSPP unified source tarball, labeled ext/ffmpeg-build. Then copy the contents of ppsspp-ffmpeg (minus all of the platform and architecture specific precompiled libraries) to a newly created ext/ffmpeg folder.

To build PPSSPP with bundled ffmpeg instead of either ppsspp-ffmpeg's prebuilt libraries or system ffmpeg, PPSSPP's CMakeLists.txt and ext/CMakeLists.txt will need to be patched using the two patches in this repository.

Then, PPSSPP can be built normally with the BUILD_BUNDLED_FFMPEG cmake option turned on.

Note: currently PPSSPP builds, but does not properly display video, using this experimental cmake port of ffmpeg. However, building ffmpeg from within this root repository using the ppsspp-ffmpeg sources and then manually bundling it with PPSSPP *does* work on my test system, so likely one or more inherited cmake flags or options set by PPSSPP cause trouble with the ffmpeg cmake build. More to follow on that front.

This bundled ffmpeg module does NOT utilize Assembly or architecture-specific optimizations. For the limited use case of ffmpeg in PPSSPP, playback of generally small H.264 videos, any gains from those optimizations are supposedly minimal yet greatly increase the complexity of porting ffmpeg to cmake.
