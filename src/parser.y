/******************************************************************************
 * Archivo:       parser.y
 * Proyecto:      Analizador Sintactico para C-- 
 * Autora:         Ana Victoria Campos Rivera A01567111
 * Fecha:         10 de junio de 2026

 *
 * Descripcion:
 *   Especificación yacc (bison, su implementacion de UNIX yacc) del analizador
 *   sintactico para el lenguaje C--. Implementa la gramática final no
 *   ambigüa descrita en la fase de Analisis. El parser se encarga de lo 
 *   siguiente:
 *     1. Verifica la estructura gramatical del flujo de tokens producido por
 *        el scanner y reporta errores sintácticos.
 *     2. Construye y actualiza una Tabla de Símbolos durante el parseo y
 *        realiza verificaciones semánticas básicas:
 *          - "declarado antes de usarse" para variables y funciones,
 *          - detección de redeclaración en el mismo ámbito,
 *          - prohibición de variables de tipo void.
 *     3. Aplica recuperación de errores mediante el token 'error' para poder
 *        continuar reportando despues de un error sintáctico.
 *     4. Contabiliza los errores léxicos para no reportar éxito cuando hubo errores.
 *
 * Estructura del archivo:
 *   - Sección de Definiciones : código C, %union, %token, precedencias.
 *   - Sección de Reglas       : producciones de la gramática con sus acciones.
 *   - Sección de Código       : yyerror, manejo de la tabla de símbolos, main.
 *
 * Estructuras del programa:
 *   - SymEntry          : registro de cada entrada en la tabla de símbolos
 *                         (name, type, kind, isArray, scope, line)
 *   - symtab            : tabla de símbolos (arreglo de SymEntry)
 *   - funcNames         : nombre de cada función
 *
 * Funciones auxiliares:
 *   - typeName          : devuelve el nombre legible de un código de tipo
 *   - semError          : reporta un error semántico y lleva el contador
 *   - lookup            : busca un identificador visible desde el ámbito actual
 *   - lookupSameScope   : busca una redeclaración en el ámbito actual
 *   - declareVar        : inserta una variable (valida void y redeclaración)
 *   - startFunction     : registra una función y abre su ámbito local
 *   - endFunction       : cierra el ámbito local (vuelve al global)
 *   - useVar            : verifica que una variable esté declarada antes de usarse
 *   - useFunc           : verifica que una funcion esté declarada antes de llamarse
 *   - initSymtab        : inicializa la tabla de símbolos
 *   - printSymtab       : imprime la tabla de símbolos formateada
 *   - yyerror           : reporta errores sintácticos (linea + léxema cercano)
 *   - main              : abre el archivo, llama a yyparse() e imprime resultados
 *
 * Compilacion
 *   yacc -d parser.y       
 *   flex  scanner.l  
 *   gcc lex.yy.c y.tab.c -o parser
 *
 * Uso:
 *   ./parser archivo.cmm
 ******************************************************************************/
/*============================== SECCION DE DEFINICIONES =====================*/
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Variables y funciones que provee el scanner generado por flex */
extern int   yylex(void);
extern int   yylineno;     /* numero de linea actual (%option yylineno) */
extern char *yytext;       /* lexema actual reconocido por el scanner   */
extern FILE *yyin;         /* archivo de entrada del scanner            */

void yyerror(const char *msg);

/*--- Codigos de tipo de dato -----------------------------------------------*/
#define T_INT     0
#define T_FLOAT   1
#define T_STRING  2
#define T_VOID    3

/*--- Clase de simbolo ------------------------------------------------------*/
#define K_VAR   0
#define K_FUNC  1

/*--- Estructura de la Tabla de Simbolos ------------------------------------*
 * Cada identificador declarado (variable o funcion) genera una entrada.     *
 * El campo 'scope' distingue el ambito: 0 = global. n mayor a 0 es ambito   *
 * local de la n-esima funcion. Las entradas NO se eliminan al terminar      *
 * solo se vuelven invisibles para la busqueda, de modo que la tabla final   *
 * impresa muestre TODOS los simbolos declarados durante el analisis.        *
 *--------------------------------------------------------------------------*/
#define MAXSYM    1000
#define MAXNAME   256

typedef struct {
    char name[MAXNAME];
    int  type;     /* T_INT, T_FLOAT, T_STRING, T_VOID */
    int  kind;     /* K_VAR o K_FUNC                   */
    int  isArray;  /* 1 si es arreglo, 0 si no */
    int  scope;    /* 0 = global; n = id de la funcion */
    int  line;     /* linea de declaracion             */
} SymEntry;

SymEntry symtab[MAXSYM];
int  symCount      = 0;

char funcNames[MAXSYM][MAXNAME]; /* nombre de cada funcion por su id de ambito */
int  currentScope  = 0;          /* 0 = global. Menor a 0, estoy dentro de una funcion     */
int  funcCounter   = 0;          /* asigna un id de ambito unico por funcion   */

int  syntaxErrors   = 0;
int  semanticErrors = 0;
int  lexical_errors = 0;   /* lo incrementa el scanner (scanner.l) */

/*--- Utilidades de impresion -----------------------------------------------*/
const char *typeName(int t) {
    switch (t) {
        case T_INT:    return "int";
        case T_FLOAT:  return "float";
        case T_STRING: return "string";
        case T_VOID:   return "void";
        default:       return "?";
    }
}

void semError(const char *msg, const char *name) {
    fprintf(stderr, "Semantic error at line %d: %s '%s'\n", yylineno, msg, name);
    semanticErrors++;
}

/*--- Operaciones sobre la Tabla de Simbolos --------------------------------*/

/* Busca un identificador visible desde el ambito actual.
 * Prioriza una declaracion local. Devuelve el indice o -1 si no es visible. */
int lookup(const char *name) {
    int i, found = -1;
    for (i = 0; i < symCount; i++) {
        if (strcmp(symtab[i].name, name) == 0) {
            if (symtab[i].scope == currentScope) return i;   /* local: prioridad */
            if (symtab[i].scope == 0)            found = i;  /* global: candidato */
        }
    }
    return found;
}

/* Busca una redeclaracion en el mismo ambito actual. */
int lookupSameScope(const char *name) {
    int i;
    for (i = 0; i < symCount; i++)
        if (symtab[i].scope == currentScope && strcmp(symtab[i].name, name) == 0)
            return i;
    return -1;
}

/* Inserta una variable en el ambito actual (global o local). */
void declareVar(int type, const char *name, int isArray) {
    if (type == T_VOID) {                 /* restriccion: no hay variables void */
        semError("'void' is not a valid type for a variable", name);
        return;
    }
    if (lookupSameScope(name) != -1) {
        semError("identifier already declared in this scope", name);
        return;
    }
    if (symCount >= MAXSYM) return;
    strncpy(symtab[symCount].name, name, MAXNAME - 1);
    symtab[symCount].name[MAXNAME - 1] = '\0';
    symtab[symCount].type    = type;
    symtab[symCount].kind    = K_VAR;
    symtab[symCount].isArray = isArray;
    symtab[symCount].scope   = currentScope;
    symtab[symCount].line    = yylineno;
    symCount++;
}

/* Registra una funcion en el ambito global y abre un nuevo ambito local. */
void startFunction(int type, const char *name) {
    if (lookupSameScope(name) != -1) {    /* currentScope vale 0 aqui (global) */
        semError("function already declared", name);
    } else if (symCount < MAXSYM) {
        strncpy(symtab[symCount].name, name, MAXNAME - 1);
        symtab[symCount].name[MAXNAME - 1] = '\0';
        symtab[symCount].type    = type;
        symtab[symCount].kind    = K_FUNC;
        symtab[symCount].isArray = 0;
        symtab[symCount].scope   = 0;     /* las funciones viven en el global   */
        symtab[symCount].line    = yylineno;
        symCount++;
    }
    funcCounter++;                        /* nuevo id de ambito para esta funcion */
    currentScope = funcCounter;
    strncpy(funcNames[currentScope], name, MAXNAME - 1);
    funcNames[currentScope][MAXNAME - 1] = '\0';
}

/* Cierra el ambito de la funcion: se vuelve al ambito global. */
void endFunction(void) {
    currentScope = 0;
}

/* Verifica que una variable este declarada antes de usarse. */
void useVar(const char *name) {
    int i = lookup(name);
    if (i == -1) {
        semError("variable not declared before use", name);
    } else if (symtab[i].kind != K_VAR) {
        semError("identifier is not a variable", name);
    }
}

/* Verifica que una funcion este declarada antes de llamarse. */
void useFunc(const char *name) {
    int i = lookup(name);
    if (i == -1) {
        semError("function not declared before use", name);
    } else if (symtab[i].kind != K_FUNC) {
        semError("identifier is not a function", name);
    }
}

void initSymtab(void) {
    symCount = 0; currentScope = 0; funcCounter = 0;
    strcpy(funcNames[0], "global");
}

void printSymtab(void) {
    int i;
    printf("\nSYMBOL TABLE\n");
    printf("-----------------------------------------------------------------------------\n");
    printf("%-20s %-8s %-9s %-7s %-12s %-5s\n",
           "Name", "Type", "Kind", "Array", "Scope", "Line");
    printf("-----------------------------------------------------------------------------\n");
    if (symCount == 0) { printf("(empty)\n"); return; }
    for (i = 0; i < symCount; i++) {
        printf("%-20s %-8s %-9s %-7s %-12s %-5d\n",
               symtab[i].name,
               typeName(symtab[i].type),
               symtab[i].kind == K_FUNC ? "function" : "variable",
               symtab[i].isArray ? "yes" : "no",
               symtab[i].scope == 0 ? "global" : funcNames[symtab[i].scope],
               symtab[i].line);
    }
}
%}

/* Tipos de valor semantico que los simbolos pueden transportar (%union). */
%union {
    char  *str;   /* lexema de ID y STRING_LITERAL          */
    int    ival;  /* valor de INTEGER y codigo de tipo      */
    double dval;  /* valor de REAL                          */
}

/* Tokens terminales. Deben coincidir con los que devuelve scanner.l.
 * bison -y -d genera y.tab.h con estas definiciones para el scanner. */
%token <str>  ID STRING_LITERAL
%token <ival> INTEGER
%token <dval> REAL

%token INT FLOAT STRING RETURN IF ELSE WHILE READ WRITE VOID
%token PLUS MINUS TIMES DIVIDE
%token LT LTE GT GTE EQ NEQ ASSIGN
%token SEMICOLON COMMA LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE

/* Tipos de los no-terminales que devuelven un valor. */
%type <ival> type_specifier
%type <str>  var

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%start program

%%
/*================================ SECCION DE REGLAS =========================*/

program
    : declaration_list
    ;

declaration_list
    : declaration_list declaration
    | declaration
    ;

declaration
    : var_declaration
    | fun_declaration
    | error SEMICOLON   { yyerrok; }   /* recuperacion a nivel declaracion */
    ;

var_declaration
    : type_specifier ID SEMICOLON
        { declareVar($1, $2, 0); free($2); }
    | type_specifier ID LBRACKET INTEGER RBRACKET SEMICOLON
        { declareVar($1, $2, 1); free($2); }
    ;

type_specifier
    : INT     { $$ = T_INT;    }
    | FLOAT   { $$ = T_FLOAT;  }
    | STRING  { $$ = T_STRING; }
    | VOID    { $$ = T_VOID;   }
    ;

fun_declaration
    : type_specifier ID LPAREN
        { startFunction($1, $2); free($2); }   /* accion embebida: abre ambito */
      params RPAREN compound_stmt
        { endFunction(); }
    ;

params
    : param_list
    | VOID
    ;

param_list
    : param_list COMMA param
    | param
    ;

param
    : type_specifier ID                       { declareVar($1, $2, 0); free($2); }
    | type_specifier ID LBRACKET RBRACKET     { declareVar($1, $2, 1); free($2); }
    ;

compound_stmt
    : LBRACE local_declarations statement_list RBRACE
    ;

local_declarations
    : local_declarations var_declaration
    | /* epsilon */
    ;

statement_list
    : statement_list statement
    | /* epsilon */
    ;

statement
    : assignment_stmt
    | call_stmt
    | compound_stmt
    | selection_stmt
    | iteration_stmt
    | return_stmt
    | input_stmt
    | output_stmt
    | error SEMICOLON   { yyerrok; }   /* recuperacion a nivel sentencia */
    ;

assignment_stmt
    : var ASSIGN expression SEMICOLON          { free($1); }
    | var ASSIGN STRING_LITERAL SEMICOLON       { free($1); free($3); }
    ;

call_stmt
    : call SEMICOLON
    ;

selection_stmt
    : IF LPAREN expression RPAREN statement                 %prec LOWER_THAN_ELSE
    | IF LPAREN expression RPAREN statement ELSE statement
    ;

iteration_stmt
    : WHILE LPAREN expression RPAREN statement
    ;

return_stmt
    : RETURN SEMICOLON
    | RETURN expression SEMICOLON
    ;

input_stmt
    : READ var SEMICOLON                        { free($2); }
    ;

output_stmt
    : WRITE expression SEMICOLON
    ;

var
    : ID                                        { useVar($1); $$ = $1; }
    | ID LBRACKET arithmetic_expression RBRACKET { useVar($1); $$ = $1; }
    ;

expression
    : arithmetic_expression relop arithmetic_expression
    | arithmetic_expression
    ;

relop
    : LTE | LT | GT | GTE | EQ | NEQ
    ;

arithmetic_expression
    : arithmetic_expression addop term
    | term
    ;

addop
    : PLUS | MINUS
    ;

term
    : term mulop factor
    | factor
    ;

mulop
    : TIMES | DIVIDE
    ;

factor
    : LPAREN arithmetic_expression RPAREN
    | var                                       { free($1); }
    | call
    | INTEGER
    | REAL
    ;

call
    : ID LPAREN args RPAREN                      { useFunc($1); free($1); }
    ;

args
    : arg_list
    | /* epsilon */
    ;

arg_list
    : arg_list COMMA arithmetic_expression
    | arithmetic_expression
    ;

%%
/*=============================== SECCION DE CODIGO ==========================*/

/* yacc llama a yyerror cuando detecta un error sintactico. Reportamos la
 * linea y el lexema cercano para dar contexto. */
void yyerror(const char *msg) {
    const char *nearToken;

    if (yytext == NULL || yytext[0] == '\0')
        nearToken = "end of file";
    else
        nearToken = yytext;

    fprintf(stderr, "Syntax error at line %d: %s near '%s'\n",
            yylineno, msg, nearToken);
    syntaxErrors++;
}

int main(int argc, char *argv[]) {
    setbuf(stdout, NULL);  
    if (argc < 2) {
        fprintf(stderr, "Usage: %s source_file.cmm\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        fprintf(stderr, "Error: could not open file %s\n", argv[1]);
        return 1;
    }

    initSymtab();
    printf("PARSING: %s\n", argv[1]);
    printf("=============================================================================\n");

    yyparse();

    printf("\n");
    if (lexical_errors == 0 && syntaxErrors == 0 && semanticErrors == 0)
        printf("RESULT: Parsing completed successfully (no lexical, syntax or semantic errors).\n");
    else
        printf("RESULT: %d lexical, %d syntax and %d semantic error(s) found.\n",
               lexical_errors, syntaxErrors, semanticErrors);

    printSymtab();

    fclose(yyin);
    return (lexical_errors || syntaxErrors || semanticErrors) ? 1 : 0;
}
