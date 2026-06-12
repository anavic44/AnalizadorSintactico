# Analizador Sintáctico para C--

**Curso:** TC3002B – Desarrollo de aplicaciones avanzadas de ciencias computacionales
**Módulo:** #3 – Compiladores
**Proyecto:** II -  Análisis Sintáctico

**Autor:** Ana Victoria Campos Rivera A01567111
**Profesor:** Rodolfo Julio Castello Zetina

---
## Descripción

Analizador sintáctico para el lenguaje C--, desarrollado con **flex** (scanner)
y **bison/yacc** (parser) sobre el lenguaje C. El parser verifica la estructura gramatical del flujo de tokens producido por el scanner y, durante el parseo, construye y actualiza una **Tabla de Símbolos** con verificaciones semánticas básicas de esta fase:

- "Declarado antes de usarse" para variables y funciones.
- Detección de redeclaración en el mismo ámbito.
- Prohibición de variables de tipo `void`.
- Manejo de ámbitos global y local (con shadowing local → global).

Incluye **recuperación de errores** mediante el token `error`, lo que permite seguir
reportando errores después del primero.

## Estructura del proyecto

```
.
├── README.md
├── Makefile                 Construcción (bison + flex + gcc) y pruebas
├── src/
│   ├── scanner.l            Scanner flex: devuelve tokens al parser
│   └── parser.y             Parser bison: gramática + tabla de símbolos + semántica
├── .gitignore               Ignora archivos generados (lex.yy.c, y.tab.*, parser, ...)
├── tests/                   8 casos de prueba
│   ├── test_programa_completo.cmm      (válido: programa completo de la especificación)
│   ├── test_valido_simple.cmm          (válido: if/else anidado, while, expresiones)
│   ├── test_sin_espacios.cmm           (válido: aritmética sin espacios, signo como operador)
│   ├── test_error_sintactico.cmm       (error sintáctico + recuperación)
│   ├── test_error_lexico.cmm           (error léxico: símbolo inválido, no reporta éxito)
│   ├── test_no_declarada.cmm           (semántico: variable no declarada)
│   ├── test_redeclarada_void.cmm       (semántico: redeclaración y variable void)
│   └── test_funcion_no_declarada.cmm   (semántico: función no declarada)
└── docs_test_output.txt     Evidencia de ejecución de los 8 casos de prueba
```

## Requisitos

- bison (>= 2.3) — se usa en modo de compatibilidad Yacc (`bison -y`)
- flex (>= 2.6)
- gcc (>= 11)
- make

## Construcción y uso

```bash
make            # genera y.tab.c/.h, lex.yy.c y el ejecutable 'parser'
make test       # ejecuta el parser sobre TODOS los tests/*.cmm (salida completa)
make test-sum   # resumen: solo la linea RESULT de cada caso de prueba
make report     # genera y.output para revisar estados y conflictos
make run FILE=tests/test_valido_simple.cmm   # ejecuta un archivo especifico
make clean      # borra archivos generados y el ejecutable
```


## Flujo de construcción (lex + yacc, como en clase)

```
bison -y -d parser.y  ->  y.tab.c , y.tab.h   (bison en modo Yacc)
flex  scanner.l     ->  lex.yy.c
gcc lex.yy.c y.tab.c -o parser
```

