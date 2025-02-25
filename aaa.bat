@echo off
echo 正在删除小部件相关文件...

cd %~dp0

:: 删除资源文件
del /q "android\app\src\main\res\xml\schedule_widget_info.xml"
del /q "android\app\src\main\res\xml\shortcuts.xml"
del /q "android\app\src\main\res\values\strings.xml"
del /q "android\app\src\main\res\layout\schedule_widget_layout.xml"
del /q "android\app\src\main\res\layout\course_item.xml"
del /q "android\app\src\main\res\drawable\widget_preview.xml"
del /q "android\app\src\main\res\drawable\widget_background.xml"
del /q "android\app\src\main\res\drawable\ic_widget.xml"
del /q "android\app\src\main\res\drawable\ic_refresh.xml"

:: 删除Kotlin文件
del /q "android\app\src\main\kotlin\com\haxinxi\schedule\ScheduleWidgetProvider.kt"

:: 删除Dart文件
del /q "lib\services\widget_service.dart"

:: 删除空文件夹
for /d %%i in (
    "android\app\src\main\res\xml",
    "android\app\src\main\res\layout",
    "android\app\src\main\res\drawable"
) do (
    dir /b "%%i\*" >nul 2>&1 || rd "%%i"
)

echo 清理完成！
echo 请记得手动清理AndroidManifest.xml和main.dart中的相关代码！
pause