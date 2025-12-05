# =============================================================================
# Makefile - Gift Ideas Generator (x86_64 Linux ASM)
# =============================================================================

# Compiler and linker
NASM     = nasm
LD       = ld

# Flags
NASMFLAGS = -felf64 -I.
LDFLAGS   =

# Directories
SRC_DIR     = src
LIB_DIR     = lib
INC_DIR     = include
BUILD_DIR   = build

# Output
TARGET = gift_core

# Source files
SRC_FILES = $(SRC_DIR)/main.asm $(SRC_DIR)/gift.asm
LIB_FILES = $(LIB_DIR)/string.asm $(LIB_DIR)/json.asm $(LIB_DIR)/memory.asm

# Object files
SRC_OBJS = $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(SRC_FILES))
LIB_OBJS = $(patsubst $(LIB_DIR)/%.asm,$(BUILD_DIR)/%.o,$(LIB_FILES))
ALL_OBJS = $(SRC_OBJS) $(LIB_OBJS)

# Include files (for dependency tracking)
INC_FILES = $(wildcard $(INC_DIR)/*.inc)

# =============================================================================
# Targets
# =============================================================================

.PHONY: all clean rebuild

all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Link all object files
$(TARGET): $(ALL_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

# Compile source files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm $(INC_FILES)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Compile library files
$(BUILD_DIR)/%.o: $(LIB_DIR)/%.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

clean:
	rm -rf $(BUILD_DIR) $(TARGET)

rebuild: clean all

# =============================================================================
# Docker targets
# =============================================================================

.PHONY: docker docker-build docker-run

docker-build:
	docker build -t gift-asm .

docker-run:
	docker run -i --rm --platform linux/amd64 --network host gift-asm

docker: docker-build docker-run

# =============================================================================
# Development helpers
# =============================================================================

.PHONY: test

test:
	@echo '{"age": 25, "interests": "gaming"}' | ./$(TARGET)
