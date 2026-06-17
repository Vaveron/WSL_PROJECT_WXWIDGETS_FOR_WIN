#!/bin/bash

# ==================== НАСТРОЙКИ ====================
# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==================== КОМПИЛЯТОРЫ ====================
CXX="x86_64-w64-mingw32-g++"
CC="x86_64-w64-mingw32-gcc"      # C компилятор для .c файлов
WINDRES="x86_64-w64-mingw32-windres"

# ==================== ПУТИ ====================
WX_DIR="$HOME/projects/Example/wxWidgets-3.2.10/windows-install"
WX_INCLUDE="$WX_DIR/include/wx-3.2"
WX_SETUP="$WX_DIR/lib/wx/include/x86_64-w64-mingw32-msw-unicode-static-3.2"
WX_LIB="$WX_DIR/lib"

# Директории проекта
SRC_DIR="src"
BUILD_DIR="build"
OBJ_DIR="$BUILD_DIR/obj"
BIN_DIR="$BUILD_DIR/bin"
LIBS_DIR="libs"
RES_DIR="resources"

# Создаём директории
mkdir -p "$OBJ_DIR" "$BIN_DIR" "$RES_DIR"

# ==================== АВТОМАТИЧЕСКИЙ ПОИСК ФАЙЛОВ ====================
# Находим все .cpp файлы (рекурсивно) в src
CPP_FILES=$(find "$SRC_DIR" -type f -name "*.cpp" 2>/dev/null)

# Находим все .c файлы в libs
C_FILES=$(find "$LIBS_DIR" -maxdepth 1 -type f -name "*.c" 2>/dev/null)

# Находим mathplot.cpp отдельно
MATHPLOT_FILE=""
if [ -f "$LIBS_DIR/mathplot.cpp" ]; then
    MATHPLOT_FILE="$LIBS_DIR/mathplot.cpp"
fi

# Находим .rc файлы
RC_FILES=$(find "$RES_DIR" -type f -name "*.rc" 2>/dev/null)
if [ -f "resources.rc" ]; then
    RC_FILES="$RC_FILES resources.rc"
fi

# Сортируем
CPP_FILES=$(echo "$CPP_FILES" | sort)
C_FILES=$(echo "$C_FILES" | sort)

# ==================== ФЛАГИ КОМПИЛЯЦИИ ====================
# Общие флаги
WX_FLAGS="-I$WX_INCLUDE -I$WX_SETUP"
WX_DEFINES="-D__WXMSW__ -D__WXDEBUG__ -DwxUSE_UNICODE=1"

# Пути для include
INCLUDE_FLAGS="-I$SRC_DIR -I$LIBS_DIR -I$RES_DIR"

# Добавляем все поддиректории src
for dir in $(find "$SRC_DIR" -type d 2>/dev/null); do
    INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
done

# Флаги для C++ компилятора
CXXFLAGS_BASE="$WX_FLAGS $WX_DEFINES $INCLUDE_FLAGS"
CXXFLAGS_BASE="$CXXFLAGS_BASE -std=c++11 -O2 -ffunction-sections -fdata-sections -Wall"

# Флаги для mathplot (подавляем предупреждения)
CXXFLAGS_MATHPLOT="$CXXFLAGS_BASE -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-variable"

# Флаги для C компилятора (для tinyexpr.c и других .c файлов)
CFLAGS="-I$LIBS_DIR -I$SRC_DIR"
CFLAGS="$CFLAGS -std=c99 -O2 -Wall"

# Флаги для ресурсов
RCFLAGS="-J rc -O coff -I$WX_INCLUDE -I$RES_DIR"

# ==================== ЛИНКОВКА ====================
LDFLAGS="-L$WX_LIB -static -mwindows -Wl,--gc-sections"
LDFLAGS="$LDFLAGS -l:libwx_mswu_core-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwx_baseu-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxpng-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxjpeg-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxtiff-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxzlib-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxregexu-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -l:libwxexpat-3.2-x86_64-w64-mingw32.a"
LDFLAGS="$LDFLAGS -lgdi32 -lole32 -loleaut32 -luuid -lcomctl32 -lcomdlg32"
LDFLAGS="$LDFLAGS -lshell32 -lshlwapi -lws2_32 -lwinmm -lversion -luxtheme"
LDFLAGS="$LDFLAGS -loleacc -lmsimg32 -lusp10 -lwinspool"

# ==================== ФУНКЦИИ ====================
error_exit() {
    echo -e "${RED}❌ Ошибка: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# ==================== ПРОВЕРКА ====================
echo ""
info "Проверка окружения..."

# Проверяем компиляторы
command -v $CXX >/dev/null 2>&1 || error_exit "C++ компилятор $CXX не найден"
command -v $CC >/dev/null 2>&1 || error_exit "C компилятор $CC не найден"

# Проверяем wxWidgets
[ ! -d "$WX_INCLUDE" ] && error_exit "wxWidgets include не найден: $WX_INCLUDE"
[ ! -d "$WX_LIB" ] && error_exit "wxWidgets lib не найден: $WX_LIB"

# Проверяем main.cpp
[ ! -f "$SRC_DIR/main.cpp" ] && error_exit "$SRC_DIR/main.cpp не найден"

echo ""
info "Найденные исходники:"

# Выводим список .cpp файлов
for file in $CPP_FILES; do
    echo "   📄 C++: $file"
done

# Выводим mathplot.cpp
if [ -n "$MATHPLOT_FILE" ]; then
    echo "   📄 C++: $MATHPLOT_FILE"
fi

# Выводим .c файлы
for file in $C_FILES; do
    echo "   📄 C:   $file"
done

# Выводим .rc файлы
for file in $RC_FILES; do
    echo "   🎨 RC:  $file"
done

# ==================== КОМПИЛЯЦИЯ РЕСУРСОВ ====================
RESOURCE_OBJECTS=""

if [ -n "$RC_FILES" ]; then
    echo ""
    info "Компиляция ресурсов..."
    
    for rc_file in $RC_FILES; do
        rc_name=$(basename "$rc_file" .rc).o
        rc_obj="$OBJ_DIR/$rc_name"
        
        echo "   Компиляция: $(basename "$rc_file")"
        $WINDRES $RCFLAGS "$rc_file" -o "$rc_obj"
        if [ $? -ne 0 ]; then
            error_exit "Не удалось скомпилировать ресурсы $rc_file"
        fi
        RESOURCE_OBJECTS="$RESOURCE_OBJECTS $rc_obj"
    done
    
    success "Ресурсы скомпилированы"
fi

# ==================== КОМПИЛЯЦИЯ C++ ФАЙЛОВ ====================
echo ""
info "Компиляция C++ файлов..."

OBJECTS=""
COMPILED_COUNT=0

# Компилируем mathplot.cpp отдельно
if [ -n "$MATHPLOT_FILE" ]; then
    echo "   Компиляция: mathplot.cpp"
    $CXX -c "$MATHPLOT_FILE" -o "$OBJ_DIR/mathplot.o" $CXXFLAGS_MATHPLO
    if [ $? -ne 0 ]; then
        error_exit "Не удалось скомпилировать mathplot.cpp"
    fi
    OBJECTS="$OBJECTS $OBJ_DIR/mathplot.o"
    ((COMPILED_COUNT++))
fi

# Компилируем остальные .cpp файлы
for file in $CPP_FILES; do
    # Создаём уникальное имя для объектного файла
    obj_name=$(echo "$file" | sed "s|$SRC_DIR/||" | sed "s|/|_|g" | sed "s|\.cpp$|.o|")
    obj_file="$OBJ_DIR/$obj_name"
    
    echo "   Компиляция: $(basename "$file")"
    $CXX -c "$file" -o "$obj_file" $CXXFLAGS_BASE
    if [ $? -ne 0 ]; then
        error_exit "Не удалось скомпилировать $file"
    fi
    OBJECTS="$OBJECTS $obj_file"
    ((COMPILED_COUNT++))
done

# ==================== КОМПИЛЯЦИЯ C ФАЙЛОВ ====================
if [ -n "$C_FILES" ]; then
    echo ""
    info "Компиляция C файлов (C компилятором)..."
    
    for file in $C_FILES; do
        obj_name=$(basename "$file" .c).o
        obj_file="$OBJ_DIR/$obj_name"
        
        echo "   Компиляция: $(basename "$file")"
        $CC -c "$file" -o "$obj_file" $CFLAGS
        if [ $? -ne 0 ]; then
            error_exit "Не удалось скомпилировать $file"
        fi
        OBJECTS="$OBJECTS $obj_file"
        ((COMPILED_COUNT++))
    done
fi

# Добавляем объекты ресурсов
if [ -n "$RESOURCE_OBJECTS" ]; then
    OBJECTS="$OBJECTS $RESOURCE_OBJECTS"
fi

success "Скомпилировано $COMPILED_COUNT файлов"

# ==================== ЛИНКОВКА ====================
echo ""
info "Линковка..."
OUTPUT="$BIN_DIR/Example.exe"

# Показываем количество объектных файлов
OBJ_COUNT=$(echo $OBJECTS | wc -w)
echo "   Объектных файлов: $OBJ_COUNT"

$CXX $OBJECTS -o "$OUTPUT" $LDFLAGS
if [ $? -ne 0 ]; then
    error_exit "Линковка"
fi

# ==================== ОПТИМИЗАЦИЯ ====================
echo ""
info "Оптимизация..."
if [ -f "$OUTPUT" ]; then
    x86_64-w64-mingw32-strip --strip-unneeded "$OUTPUT" 2>/dev/null
fi

# ==================== ИТОГИ ====================
echo ""
echo "═══════════════════════════════════════════════════════════"
success "Сборка завершена успешно!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📊 Статистика:"
echo "   📁 Папка: $(pwd)"
echo "   📄 Файл: $OUTPUT"
echo "   📦 Размер: $(du -h "$OUTPUT" | cut -f1)"
echo "   📝 Файлов скомпилировано: $COMPILED_COUNT"
if [ -n "$RESOURCE_OBJECTS" ]; then
    echo "   🎨 Ресурсов скомпилировано: $(echo $RESOURCE_OBJECTS | wc -w)"
fi
echo "💡 Копирование на рабочий стол:"
echo "   cp $OUTPUT /mnt/c/Users/andrew/Desktop/"
echo ""

# ==================== ОПЦИИ ====================
if [ "$1" == "clean" ]; then
    echo ""
    info "Очистка..."
    rm -rf "$OBJ_DIR"/*.o "$BIN_DIR"/*.exe
    success "Очищено"
fi