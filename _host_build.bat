@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 ( echo VCVARS_FAILED & exit /b 1 )
cmake --build build-host --target conversation_cache_test conversation_memory_test conversation_file_test conversation_spill_test conversation_prompt_cache_test stage_plan_test agenda_test -j 8
exit /b %errorlevel%
