/******************************************************************************
 * Archivo:       scanner.l
 * Proyecto:      Analizador sintáctico para C--
 * Autora:        Ana Victoria Campos Rivera, A01567111
 * Fecha:         10 de junio de 2026
 *
 * Descripción:
 * Especificación Flex del analizador léxico para C--, adaptada para la fase de
 * análisis sintáctico. A diferencia de la fase de análisis léxico, en la que
 * el scanner se encargaba de imprimir los tokens y construir las tablas, en
 * esta fase el scanner funciona como proveedor de tokens para el parser.
 *
 * El scanner devuelve la constante del token definida por Yacc en y.tab.h para
 * cada lexema reconocido. Cuando el token transporta un valor semántico, como
 * un identificador, número o cadena, dicho valor se almacena en yylval.
 *
 * Cambios con respecto a la entrega del analizador léxico:
 *   1. Se incluye "y.tab.h" para utilizar los códigos de token generados por
 *      Yacc.
 *   2. Cada regla devuelve el token correspondiente y, cuando aplica, asigna
 *      su valor semántico a yylval.
 *   3. Los comentarios se reconocen mediante una sola expresión regular, en
 *      lugar de utilizar el estado exclusivo %x COMMENT.
 *   4. La función main() ya no se encuentra en este archivo, debido a que está
 *      definida en parser.y.
 *
 * Compilación:
 *   yacc -d parser.y
 *   flex scanner.l
 *   gcc y.tab.c lex.yy.c -o parser
 ******************************************************************************/
%option noyywrap
%option yylineno
%option nounput
%option nodefault

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"        /* codigos de token y union YYSTYPE generados por yacc */

extern int lexical_errors; /* contador de errores lexicos (definido en parser.y) */
%}

/*--- Definiciones regulares -----------------------------------------------*/
LETTER      [A-Za-z]
DIGIT       [0-9]
ID          ({LETTER}({LETTER}|{DIGIT}|_)*|_({LETTER}|{DIGIT})({LETTER}|{DIGIT}|_)*)
INTEGER     {DIGIT}+
REAL        {DIGIT}+\.{DIGIT}+
STRING_LIT  \"[^\n\"]*\"
COMMENT     \/\*([^*]|\*+[^*/])*\*+\/

/*--- Patrones de errores lexicos -------------------------------------------*/
INVALID_ID_DIGIT       {DIGIT}+({LETTER}|_)({LETTER}|{DIGIT}|_)*
INVALID_REAL_TWO_DOTS  {DIGIT}+\.{DIGIT}+\.({DIGIT}|{LETTER}|_)*
INVALID_REAL_END_DOT   {DIGIT}+\.
INVALID_REAL_NO_INT    \.{DIGIT}+
INVALID_REAL_SUFFIX    {DIGIT}+\.{DIGIT}+({LETTER}|_)({LETTER}|{DIGIT}|_)*
INVALID_ID_UNDERSCORE  (_|__({LETTER}|{DIGIT}|_)*)

%%
{BLANK}+                    { /* se ignoran los espacios en blanco */ }
{COMMENT}                   { /* se ignoran los comentarios bien formados */ }
"/*"                        { int c;
                              fprintf(stderr, "Lexical error at line %d: unclosed comment\n", yylineno);
                              lexical_errors++;
                              while ((c = input()) != EOF) { /* consume el resto del archivo */ } }

{INVALID_ID_DIGIT}          { fprintf(stderr, "Lexical error at line %d: invalid identifier '%s'\n", yylineno, yytext); lexical_errors++; }
{INVALID_REAL_SUFFIX}       { fprintf(stderr, "Lexical error at line %d: invalid real number '%s'\n", yylineno, yytext); lexical_errors++; }
{INVALID_REAL_TWO_DOTS}     { fprintf(stderr, "Lexical error at line %d: invalid real number '%s'\n", yylineno, yytext); lexical_errors++; }
{INVALID_REAL_END_DOT}      { fprintf(stderr, "Lexical error at line %d: invalid real number '%s'\n", yylineno, yytext); lexical_errors++; }
{INVALID_REAL_NO_INT}       { fprintf(stderr, "Lexical error at line %d: invalid real number '%s'\n", yylineno, yytext); lexical_errors++; }
{INVALID_ID_UNDERSCORE}     { fprintf(stderr, "Lexical error at line %d: invalid identifier '%s'\n", yylineno, yytext); lexical_errors++; }
\"[^\n\"]*                  { fprintf(stderr, "Lexical error at line %d: unclosed string '%s'\n", yylineno, yytext); lexical_errors++; }

 /* Palabras reservadas */
[Ii][Nn][Tt]                { return INT;    }
[Ff][Ll][Oo][Aa][Tt]        { return FLOAT;  }
[Ss][Tt][Rr][Ii][Nn][Gg]    { return STRING; }
[Rr][Ee][Tt][Uu][Rr][Nn]    { return RETURN; }
[Ii][Ff]                    { return IF;     }
[Ee][Ll][Ss][Ee]            { return ELSE;   }
[Ww][Hh][Ii][Ll][Ee]        { return WHILE;  }
[Rr][Ee][Aa][Dd]            { return READ;   }
[Ww][Rr][Ii][Tt][Ee]        { return WRITE;  }
[Vv][Oo][Ii][Dd]            { return VOID;   }

 /* Tokens con valor: numeros, cadenas e identificadores */
{REAL}                      { yylval.dval = atof(yytext); return REAL;    }
{INTEGER}                   { yylval.ival = atoi(yytext); return INTEGER; }
{STRING_LIT}                { yylval.str  = strdup(yytext); return STRING_LITERAL; }
{ID}                        { yylval.str  = strdup(yytext); return ID; }

 /* Operadores (los de dos caracteres van primero) */
"<="                        { return LTE; }
">="                        { return GTE; }
"=="                        { return EQ;  }
"!="                        { return NEQ; }
"!"                         { fprintf(stderr, "Lexical error at line %d: invalid operator '%s'\n", yylineno, yytext); lexical_errors++; }
"<"                         { return LT;  }
">"                         { return GT;  }
"="                         { return ASSIGN; }
"+"                         { return PLUS;   }
"-"                         { return MINUS;  }
"*"                         { return TIMES;  }
"/"                         { return DIVIDE; }

 /* Delimitadores */
";"                         { return SEMICOLON; }
","                         { return COMMA;     }
"("                         { return LPAREN;    }
")"                         { return RPAREN;    }
"["                         { return LBRACKET;  }
"]"                         { return RBRACKET;  }
"{"                         { return LBRACE;    }
"}"                         { return RBRACE;    }

.                           { fprintf(stderr, "Lexical error at line %d: invalid symbol '%s'\n", yylineno, yytext); lexical_errors++; }

%%