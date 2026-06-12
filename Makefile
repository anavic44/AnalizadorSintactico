# Makefile - Analizador Sintactico C-- (Proyecto II)
# Autor: Ana Victoria Campos Rivera A01567111
#
# Flujo de construccion:
#   bison -y -d parser.y  ->  y.tab.c , y.tab.h
#   flex  scanner.l       ->  lex.yy.c
#   gcc lex.yy.c y.tab.c -o parser
#==============================================================================
CC      = gcc
CFLAGS  = -Wall -Wextra -g
LEX     = flex
YACC    = bison -y

TARGET  = parser
LSOURCE = src/scanner.l
YSOURCE = src/parser.y

GEN_C   = lex.yy.c y.tab.c
GEN_H   = y.tab.h

# Casos de prueba incluidos en el proyecto (carpeta tests/).
TESTS   = $(wildcard tests/*.cmm)

$(TARGET): $(GEN_C)
	$(CC) $(CFLAGS) lex.yy.c y.tab.c -o $(TARGET)

y.tab.c y.tab.h: $(YSOURCE)
	$(YACC) -d $(YSOURCE)

lex.yy.c: $(LSOURCE) y.tab.h
	$(LEX) $(LSOURCE)

# Reporta conflictos de la gramatica (archivo y.output)
report: $(YSOURCE)
	$(YACC) -d -v $(YSOURCE)
	@echo "Revisa y.output para el detalle de estados y conflictos."

# Ejecuta el parser sobre cada caso de prueba mostrando su salida completa.
test: $(TARGET)
	@for f in $(TESTS); do \
		echo "============================================================"; \
		echo "TEST: $$f"; \
		echo "============================================================"; \
		./$(TARGET) $$f; \
		echo ""; \
	done

# Resumen: solo la linea RESULT de cada caso.
test-sum: $(TARGET)
	@for f in $(TESTS); do \
		printf "%-38s " "$$f"; \
		./$(TARGET) $$f 2>/dev/null | grep RESULT; \
	done

run: $(TARGET)
	./$(TARGET) $(FILE)

clean:
	rm -f $(GEN_C) $(GEN_H) y.output $(TARGET)

.PHONY: report test test-sum run clean