@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 ( echo VCVARS_FAILED & exit /b 1 )
cmake -G Ninja -S . -B build-host ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DSTRATA_BUILD_CONVERSATION_TESTS=ON ^
  -DSTRATA_BUILD_TESTS=OFF ^
  -DSTRATA_NATIVE_EXPERTS=OFF ^
  -DSTRATA_ENABLE_CUDA=OFF
exit /b %errorlevel%
