/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
 *
 * Copyright 2024 Olaf Wintermann. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef IM4_regexreplace_h
#define IM4_regexreplace_h

#include <stdlib.h>
#include <sys/types.h>

#include <regex.h>

#define REGEX_TEXT_REPLACEMENT_RULES_FILE "regex-text-replacement.rules"

typedef struct TextReplacementRule {
    /*
     * regex pattern
     */
    char *pattern;
    
    /*
     * replacement string
     * If the string contains "$1", it is replaced with the first capture group
     * Escaping rules:
     * \$: "$"
     * \t: <tab>
     * \n: <newline>
     */
    char *replacement;
    
    /*
     * compiled regex
     */
    regex_t regex;
    
    /*
     * regex compiled successfully
     */
    int compiled;
} TextReplacementRule;


// ------------------------- config -------------------------

int load_rules_config(const char *file);

/*
 * Loads text replacement rules from a rules definition file
 *
 * Format:
 * # comment
 * <pattern>\t<replacement>
 *
 */
int load_rules(const char *file, TextReplacementRule **rules, size_t *len);

/*
 * Frees a TextReplacementRule array, including all pattern and replacement
 * strings and the compiled regex pattern
 */
void free_rules(TextReplacementRule *rules, size_t nelm);

/*
 * returns the array of loaded text replacement rules
 */
TextReplacementRule* get_rules(size_t *numelm);



// ------------------------- regex replace -------------------------

/*
 * Replace all occurrences of str in in with replacement
 *
 * Also unescapes: \t \n \$ \\
 */
char* str_unescape_and_replace(
        const char *in,
        const char *str,
        const char *replacement);

/*
 * Applies the text replacement rule to msg_in
 * If the rule pattern matches, msg_in is freed with (g_free) and a new string
 * is returned, allocated with g_malloc
 * If no match is found, the original string ptr is returned
 */
char* apply_rule(char *msg_in, TextReplacementRule *rule);

/*
 * apply all (compiled) rules to msg
 */
void apply_all_rules(char **msg);

#endif /* IM4_regexreplace_h */
