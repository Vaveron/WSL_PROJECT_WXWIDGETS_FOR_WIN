#!/bin/bash

# ==================== НАСТРОЙКИ ====================
# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Имя проекта (определяется автоматически)
PROJECT_NAME=$(basename "$(pwd)")

# ==================== ПАРСИНГ АРГУМЕНТОВ ====================
TARGET_OS=""

for arg in "$@"; do
    case $arg in
        win|windows)
            TARGET_OS="windows"
            ;;
        lin|linux)
            TARGET_OS="linux"
            ;;
        all|both)
            TARGET_OS="all"
            ;;
        clean)
            echo -e "${YELLOW}🧹 Очистка...${NC}"
            rm -rf build/obj/* build/bin/* 2>/dev/null
            echo -e "${GREEN}✅ Очищено${NC}"
            exit 0
            ;;
        --help|-h)
            echo -e "${CYAN}Использование: ./build.sh [опция]${NC}"
            echo ""
            echo -e "${YELLOW}Опции:${NC}"
            echo "  win, windows    - Сборка для Windows"
            echo "  lin, linux      - Сборка для Linux"
            echo "  all, both       - Сборка для Windows и Linux одновременно"
            echo "  clean           - Очистить сборку"
            echo "  --help, -h      - Показать эту справку"
            echo ""
            echo -e "${YELLOW}Примеры:${NC}"
            echo "  ./build.sh win         - Сборка для Windows"
            echo "  ./build.sh lin         - Сборка для Linux"
            echo "  ./build.sh all         - Сборка для Windows и Linux"
            echo "  ./build.sh clean       - Очистка"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Неизвестная опция: $arg${NC}"
            echo "Используйте ./build.sh --help для справки"
            exit 1
            ;;
    esac
done

# Если ОС не указана - определяем автоматически
if [ -z "$TARGET_OS" ]; then
    if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "mingw"* ]]; then
        TARGET_OS="windows"
        echo -e "${YELLOW}⚠️ ОС не указана, автоматически выбрана Windows${NC}"
    else
        TARGET_OS="linux"
        echo -e "${YELLOW}⚠️ ОС не указана, автоматически выбрана Linux${NC}"
    fi
fi

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

header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${MAGENTA}$1${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# ==================== ПОИСК WXWIDGETS ====================
find_wxwidgets() {
    local os="$1"
    local wx_paths=(
        "$(pwd)/windows-install"
        "/usr/local/wxWidgets"
        "/opt/wxWidgets"
    )
    
    if [ "$os" == "windows" ]; then
        for path in "${wx_paths[@]}"; do
            if [ -d "$path/include/wx-3.2" ] && [ -d "$path/lib" ]; then
                echo "$path"
                return 0
            fi
        done
        # Проверяем системный путь для Windows (MSYS2)
        if [ -d "/mingw64/include/wx-3.2" ]; then
            echo "/mingw64"
            return 0
        fi
        if [ -d "/usr/include/wx-3.2" ]; then
            echo "/usr"
            return 0
        fi
    else
        # Linux - системный
        if [ -d "/usr/include/wx-3.2" ]; then
            echo "/usr"
            return 0
        fi
    fi
    
    return 1
}

# ==================== ФУНКЦИЯ СБОРКИ ====================
build_for_os() {
    local os="$1"
    local build_name="$2"
    
    header "🎯 Сборка для $build_name"
    info "$BUILDER_VERSION"
    # ========== НАСТРОЙКА КОМПИЛЯТОРОВ ==========
    if [ "$os" == "windows" ]; then
        CXX="x86_64-w64-mingw32-g++"
        CC="x86_64-w64-mingw32-gcc"
        WINDRES="x86_64-w64-mingw32-windres"
        
        WX_DEFINES="-D__WXMSW__ -D__WXDEBUG__ -DwxUSE_UNICODE=1"
        
        # Ищем wxWidgets
        WX_BASE=$(find_wxwidgets "windows")
        if [ -z "$WX_BASE" ]; then
            echo -e "${RED}❌ wxWidgets не найден для Windows!${NC}"
            echo "Искал в:"
            echo "  - $(pwd)/windows-install"
            echo "  - /mingw64"
            echo "  - /usr"
            return 1
        fi
        
        # Определяем пути
        if [ "$WX_BASE" == "/mingw64" ] || [ "$WX_BASE" == "/usr" ]; then
            WX_INCLUDE="$WX_BASE/include/wx-3.2"
            if [ "$WX_BASE" == "/mingw64" ]; then
                WX_SETUP="/mingw64/lib/wx/include/x86_64-w64-mingw32-msw-unicode-3.2"
                WX_LIB="/mingw64/lib"
            else
                WX_SETUP="/usr/lib/wx/include/x86_64-w64-mingw32-msw-unicode-3.2"
                WX_LIB="/usr/lib"
            fi
        else
            WX_INCLUDE="$WX_BASE/include/wx-3.2"
            WX_SETUP="$WX_BASE/lib/wx/include/x86_64-w64-mingw32-msw-unicode-static-3.2"
            WX_LIB="$WX_BASE/lib"
        fi
        
        echo -e "${BLUE}📋 wxWidgets: $WX_BASE${NC}"
        
        LDFLAGS="-L$WX_LIB -static -mwindows -Wl,--gc-sections"
        
        # Ищем библиотеки
        if [ -f "$WX_LIB/libwx_mswu_core-3.2-x86_64-w64-mingw32.a" ]; then
            LDFLAGS="$LDFLAGS -l:libwx_mswu_core-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwx_baseu-3.2-x86_64-w64-mingw32.a"
        elif [ -f "$WX_LIB/libwx_mswu_core-3.2.a" ]; then
            LDFLAGS="$LDFLAGS -lwx_mswu_core-3.2 -lwx_baseu-3.2"
        else
            LDFLAGS="$LDFLAGS -lwx_mswu_core -lwx_baseu"
        fi
        
        # Дополнительные библиотеки
        if [ "$WX_BASE" != "/mingw64" ] && [ "$WX_BASE" != "/usr" ]; then
            LDFLAGS="$LDFLAGS -l:libwxpng-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwxjpeg-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwxtiff-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwxzlib-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwxregexu-3.2-x86_64-w64-mingw32.a"
            LDFLAGS="$LDFLAGS -l:libwxexpat-3.2-x86_64-w64-mingw32.a"
        fi
        
        LDFLAGS="$LDFLAGS -lgdi32 -lole32 -loleaut32 -luuid -lcomctl32 -lcomdlg32"
        LDFLAGS="$LDFLAGS -lshell32 -lshlwapi -lws2_32 -lwinmm -lversion -luxtheme"
        LDFLAGS="$LDFLAGS -loleacc -lmsimg32 -lusp10 -lwinspool"
        
        EXE_SUFFIX=".exe"
        OUTPUT_NAME="${PROJECT_NAME}_Win.exe"
        
        # Флаги для ресурсов
        RCFLAGS="-J rc -O coff -I$WX_INCLUDE"
        
        # Поиск .rc файлов
        RC_FILES=$(find . -maxdepth 2 -type f -name "*.rc" 2>/dev/null)
        
    elif [ "$os" == "linux" ]; then
        CXX="g++"
        CC="gcc"
        WINDRES="windres"
        
        # Ищем wxWidgets
        WX_BASE=$(find_wxwidgets "linux")
        if [ -z "$WX_BASE" ]; then
            echo -e "${RED}❌ wxWidgets не найден для Linux!${NC}"
            echo "Установите: sudo apt-get install libwxgtk3.2-dev libwxbase3.2-dev"
            return 1
        fi
        
        WX_INCLUDE="$WX_BASE/include/wx-3.2"
        if [ "$WX_BASE" == "/usr" ]; then
            WX_SETUP="/usr/lib/x86_64-linux-gnu/wx/include/gtk3-unicode-3.2"
            WX_LIB="/usr/lib/x86_64-linux-gnu"
        else
            WX_SETUP="$WX_BASE/lib/wx/include/gtk3-unicode-3.2"
            WX_LIB="$WX_BASE/lib"
        fi
        
        echo -e "${BLUE}📋 wxWidgets: $WX_BASE${NC}"
        
        WX_DEFINES="-D__WXGTK__ -DwxUSE_UNICODE=1"
        
        LDFLAGS="-L$WX_LIB -lwx_gtk3u_core-3.2 -lwx_baseu-3.2"
        LDFLAGS="$LDFLAGS -lgtk-3 -lgdk-3 -lgio-2.0 -lgobject-2.0 -lglib-2.0"
        LDFLAGS="$LDFLAGS -lX11 -lXxf86vm -lGL -lGLU"
        
        EXE_SUFFIX=""
        OUTPUT_NAME="${PROJECT_NAME}_Linux"
        
        RC_FILES=""
    fi
    
    # ========== ПРОВЕРКА ==========
    echo -e "${BLUE}📋 Компилятор: $CXX${NC}"
    echo ""
    
    command -v $CXX >/dev/null 2>&1 || { echo -e "${RED}❌ Компилятор $CXX не найден${NC}"; return 1; }
    [ ! -f "$WX_INCLUDE/wx/wx.h" ] && { echo -e "${RED}❌ wxWidgets не найден в $WX_INCLUDE${NC}"; return 1; }
    
    # Проверяем main.cpp
    MAIN_FILE=$(find "$SRC_DIR" -name "main.cpp" 2>/dev/null | head -1)
    [ -z "$MAIN_FILE" ] && MAIN_FILE=$(find . -maxdepth 2 -name "main.cpp" 2>/dev/null | head -1)
    [ -z "$MAIN_FILE" ] && { echo -e "${RED}❌ main.cpp не найден${NC}"; return 1; }
    
    # ========== ДИРЕКТОРИИ ==========
    SRC_DIR=$(dirname "$MAIN_FILE")
    if [ "$SRC_DIR" == "." ]; then
        SRC_DIR="src"
    fi
    
    BUILD_DIR="build"
    OBJ_DIR="$BUILD_DIR/obj"
    BIN_DIR="$BUILD_DIR/bin"
    LIBS_DIR="libs"
    RES_DIR="resources"
    
    mkdir -p "$OBJ_DIR" "$BIN_DIR" "$RES_DIR" 2>/dev/null
    
    # ========== ПОИСК ФАЙЛОВ ==========
    CPP_FILES=$(find "$SRC_DIR" -type f -name "*.cpp" 2>/dev/null | sort)
    C_FILES=$(find "$LIBS_DIR" -maxdepth 1 -type f -name "*.c" 2>/dev/null | sort 2>/dev/null)
    MATHPLOT_FILE=""
    [ -f "$LIBS_DIR/mathplot.cpp" ] && MATHPLOT_FILE="$LIBS_DIR/mathplot.cpp"
    
    # ========== ФЛАГИ ==========
    WX_FLAGS="-I$WX_INCLUDE -I$WX_SETUP"
    INCLUDE_FLAGS="-I$SRC_DIR -I$LIBS_DIR -I$RES_DIR"
    
    for dir in $(find "$SRC_DIR" -type d 2>/dev/null); do
        INCLUDE_FLAGS="$INCLUDE_FLAGS -I$dir"
    done
    
    CXXFLAGS_BASE="$WX_FLAGS $WX_DEFINES $INCLUDE_FLAGS"
    CXXFLAGS_BASE="$CXXFLAGS_BASE -std=c++11 -O2 -ffunction-sections -fdata-sections -Wall"
    CXXFLAGS_MATHPLOT="$CXXFLAGS_BASE -Wno-deprecated-declarations -Wno-unused-parameter -Wno-unused-variable"
    CFLAGS="-I$LIBS_DIR -I$SRC_DIR -std=c99 -O2 -Wall"
    
    # ========== ВЫВОД ФАЙЛОВ ==========
    info "Найденные исходники:"
    for file in $CPP_FILES; do
        echo "   📄 C++: $file"
    done
    [ -n "$MATHPLOT_FILE" ] && echo "   📄 C++: $MATHPLOT_FILE"
    for file in $C_FILES; do
        echo "   📄 C:   $file"
    done
    if [ -n "$RC_FILES" ] && [ "$os" == "windows" ]; then
        for file in $RC_FILES; do
            echo "   🎨 RC:  $file"
        done
    fi
    echo ""
    
    # ========== КОМПИЛЯЦИЯ РЕСУРСОВ ==========
    RESOURCE_OBJECTS=""
    
    if [ -n "$RC_FILES" ] && [ "$os" == "windows" ]; then
        info "Компиляция ресурсов..."
        for rc_file in $RC_FILES; do
            rc_name=$(basename "$rc_file" .rc).o
            rc_obj="$OBJ_DIR/${os}_$rc_name"
            echo "   Компиляция: $(basename "$rc_file")"
            $WINDRES $RCFLAGS "$rc_file" -o "$rc_obj" 2>/dev/null || warning "Не удалось скомпилировать ресурсы $rc_file (пропускаем)"
            [ -f "$rc_obj" ] && RESOURCE_OBJECTS="$RESOURCE_OBJECTS $rc_obj"
        done
        [ -n "$RESOURCE_OBJECTS" ] && success "Ресурсы скомпилированы"
        echo ""
    fi
    
    # ========== КОМПИЛЯЦИЯ ==========
    info "Компиляция..."
    
    OBJECTS=""
    COMPILED_COUNT=0
    
    # mathplot.cpp
    if [ -n "$MATHPLOT_FILE" ]; then
        obj_file="$OBJ_DIR/${os}_mathplot.o"
        echo "   Компиляция: mathplot.cpp"
        $CXX -c "$MATHPLOT_FILE" -o "$obj_file" $CXXFLAGS_MATHPLOT 2>/dev/null || warning "Не удалось скомпилировать mathplot.cpp (пропускаем)"
        [ -f "$obj_file" ] && { OBJECTS="$OBJECTS $obj_file"; ((COMPILED_COUNT++)); }
    fi
    
    # .cpp файлы
    for file in $CPP_FILES; do
        obj_name=$(basename "$file" .cpp).o
        obj_file="$OBJ_DIR/${os}_$obj_name"
        echo "   Компиляция: $(basename "$file")"
        $CXX -c "$file" -o "$obj_file" $CXXFLAGS_BASE || error_exit "Не удалось скомпилировать $file"
        OBJECTS="$OBJECTS $obj_file"
        ((COMPILED_COUNT++))
    done
    
    # .c файлы
    if [ -n "$C_FILES" ]; then
        for file in $C_FILES; do
            obj_name=$(basename "$file" .c).o
            obj_file="$OBJ_DIR/${os}_$obj_name"
            echo "   Компиляция: $(basename "$file")"
            $CC -c "$file" -o "$obj_file" $CFLAGS || error_exit "Не удалось скомпилировать $file"
            OBJECTS="$OBJECTS $obj_file"
            ((COMPILED_COUNT++))
        done
    fi
    
    # Добавляем ресурсы
    if [ -n "$RESOURCE_OBJECTS" ]; then
        OBJECTS="$OBJECTS $RESOURCE_OBJECTS"
    fi
    
    [ $COMPILED_COUNT -gt 0 ] && success "Скомпилировано $COMPILED_COUNT файлов"
    echo ""
    
    # ========== ЛИНКОВКА ==========
    if [ -z "$OBJECTS" ]; then
        warning "Нет объектных файлов для линковки!"
        return 1
    fi
    
    info "Линковка..."
    OUTPUT="$BIN_DIR/$OUTPUT_NAME"
    
    OBJ_COUNT=$(echo $OBJECTS | wc -w)
    echo "   Объектных файлов: $OBJ_COUNT"
    
    $CXX $OBJECTS -o "$OUTPUT" $LDFLAGS || error_exit "Линковка"
    
    # ========== ОПТИМИЗАЦИЯ ==========
    if [ -f "$OUTPUT" ]; then
        if [ "$os" == "windows" ]; then
            x86_64-w64-mingw32-strip --strip-unneeded "$OUTPUT" 2>/dev/null
        else
            strip --strip-unneeded "$OUTPUT" 2>/dev/null
        fi
    fi
    
    # ========== ИТОГИ ==========
    echo ""
    success "Сборка для $build_name завершена!"
    echo "   📄 Файл: $OUTPUT"
    echo "   📦 Размер: $(du -h "$OUTPUT" 2>/dev/null | cut -f1 || echo 'неизвестно')"
    echo ""
    
    return 0
}

# ==================== ЗАПУСК СБОРКИ ====================
START_TIME=$(date +%s)
BUILDER_VERSION="Сборщик v0.2 @MrVaveron"
if [ "$TARGET_OS" == "all" ]; then
    header "🏗️  СБОРКА ДЛЯ WINDOWS И LINUX"
    echo -e "${CYAN}Сборка для обеих платформ...${NC}"
    echo ""
    info "$BUILDER_VERSION"
    build_for_os "windows" "Windows"
    WIN_RESULT=$?
    
    build_for_os "linux" "Linux"
    LIN_RESULT=$?
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    header "📊 ИТОГИ СБОРКИ"
    
    if [ $WIN_RESULT -eq 0 ] && [ $LIN_RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ Обе сборки завершены успешно!${NC}"
        echo ""
        echo -e "${BLUE}📁 Файлы:${NC}"
        echo "   🪟 Windows: build/bin/${PROJECT_NAME}_Win_.exe"
        echo "   🐧 Linux:   build/bin/${PROJECT_NAME}_Linux"
    else
        echo -e "${RED}❌ Одна из сборок завершилась с ошибкой${NC}"
        [ $WIN_RESULT -ne 0 ] && echo "   ❌ Windows: ошибка"
        [ $LIN_RESULT -ne 0 ] && echo "   ❌ Linux: ошибка"
    fi
    echo ""
    echo -e "${YELLOW}⏱️  Общее время: ${DURATION} сек${NC}"
    info "$BUILDER_VERSION"
    
elif [ "$TARGET_OS" == "windows" ]; then
    build_for_os "windows" "Windows"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo -e "${YELLOW}⏱️  Время сборки: ${DURATION} сек${NC}"
    echo ""
    echo "💡 Запуск через wine:"
    echo "   wine build/bin/${PROJECT_NAME}_Win.exe"
    echo ""
    echo "💡 В Windows:"
    echo "   \\\\wsl.localhost\\Ubuntu\\$(pwd)/build/bin/${PROJECT_NAME}_Win.exe"
    info "$BUILDER_VERSION"
    
elif [ "$TARGET_OS" == "linux" ]; then
    build_for_os "linux" "Linux"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo -e "${YELLOW}⏱️  Время сборки: ${DURATION} сек${NC}"
    echo ""
    echo "💡 Запуск:"
    echo "   ./build/bin/${PROJECT_NAME}_Linux"
    info "$BUILDER_VERSION"
fi