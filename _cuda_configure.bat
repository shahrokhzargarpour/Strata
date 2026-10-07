@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 ( echo VCVARS_FAILED & exit /b 1 )
cmake -G Ninja -S . -B build-cuda ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DSTRATA_ENABLE_CUDA=ON ^
  -DSTRATA_EXPERIMENTAL_SM60=ON ^
  "-DCMAKE_CUDA_ARCHITECTURES=86;89" ^
  -DCMAKE_CUDA_COMPILER="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.8/bin/nvcc.exe" ^
  -DSTRATA_GGML_DIR="D:/AI/repos/asistentes/Strata-main/third_party/llama.cpp" ^
  -DSTRATA_BUILD_TESTS=OFF ^
  -DSTRATA_BUILD_CONVERSATION_TESTS=ON
exit /b %errorlevel%
