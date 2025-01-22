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

// This file is based on pidgin-regex-text-replacement
// https://github.com/unixwork/pidgin-regex-text-replacement.git


#include "regexreplace.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdbool.h>

static TextReplacementRule *rules;
static size_t nrules;

int load_rules_config(const char *file) {
    return load_rules(file, &rules, &nrules);
}

int load_rules(const char *file, TextReplacementRule **rules, size_t *len) {
    *rules = NULL;
    *len = 0;
    
    FILE *in = fopen(file, "r");
    if(!in) {
        if(errno == ENOENT) {
            FILE *out = fopen(file, "w");
            fputs("?v1\n", out);
            fclose(out);
            return 0;
        }
        return 1;
    }
    
    size_t rules_alloc = 16;
    size_t rules_size = 0;
    TextReplacementRule *r = calloc(rules_alloc, sizeof(TextReplacementRule));
      
    char *line = NULL;
    size_t linelen = 0;
    
    // read format version
    size_t vlen = getline(&line, &linelen, in);
    if(vlen == 0) {
        free(line);
        fclose(in);
        return 0;
    }
    
    if(line[vlen-1] == '\n') {
        line[vlen-1] = 0;
    }
    if(strcmp(line, "?v1")) {
        fprintf(stderr, "Unknown file format version: %s\n", line);
        free(line);
        fclose(in);
        return 1;
    }
    
    // read rules
    while(getline(&line, &linelen, in) >= 0) {
        char *ln = line;
        size_t lnlen = strlen(ln);
        
        // remove trailing newline
        if(lnlen > 0 && ln[lnlen-1] == '\n') {
            ln[lnlen-1] = '\0';
            lnlen--;
        }
        
        if(lnlen == 0) {
            continue;
        }
        
        // find first \t separator
        int separator = 0;
        for(int i=0;i<lnlen;i++) {
            if(ln[i] == '\t') {
                separator = i;
                break;
            }
        }
        
        // if a separator was found, we can add the rule
        if(separator > 0) {
            ln[separator] = '\0';
            
            char *pattern = strdup(ln);
            char *replacement = strdup(ln+separator+1);
            
            if(rules_size == rules_alloc) {
                rules_alloc *= 2;
                r = realloc(r, rules_alloc * sizeof(TextReplacementRule));
            }
            r[rules_size].pattern = pattern;
            r[rules_size].replacement = replacement;
            
            // compile the rule
            if(regcomp(&r[rules_size].regex, ln, REG_EXTENDED) == 0) {
                r[rules_size].compiled = true;
            } else {
                fprintf(stderr, "Cannot compile pattern: %s\n", ln);
            }
            
            rules_size++;
        } else {
            fprintf(stderr, "Invalid text replacement rule: %s\n", ln);
        }
    }
    fclose(in);
    if(line) {
        free(line);
    }
    
    *rules = r;
    *len = rules_size;
    
    return 0;
}

TextReplacementRule* get_rules(size_t *numelm) {
    *numelm = nrules;
    return rules;
}

int rule_update_pattern(size_t index, char *new_pattern) {
    if(index >= nrules) {
        return 0;
    }
    TextReplacementRule *rule = &rules[index];
    free(rule->pattern);
    if(rule->compiled) {
        regfree(&rule->regex);
    }
    
    rule->pattern = strdup(new_pattern);
    if(strlen(new_pattern) > 0) {
        rule->compiled = regcomp(&rule->regex, new_pattern, REG_EXTENDED) == 0;
    } else {
        rule->compiled = 0;
    }
    
    return rule->compiled;
}

void rule_update_replacement(size_t index, char *new_replacement) {
    if(index >= nrules) {
        return;
    }
    TextReplacementRule *rule = &rules[index];
    free(rule->replacement);
    rule->replacement = strdup(new_replacement);
}

void rule_remove(size_t index) {
    if(index >= nrules) {
        fprintf(stderr, "rules array out of bounds: %d\n", (int)index);
        return;
    }
    TextReplacementRule *r = &rules[index];
    free(r->pattern);
    free(r->replacement);
    if(r->compiled) {
        regfree(&r->regex);
    }
    
    if(index+1 < nrules) {
        memmove(rules+index, rules+index+1, (nrules-index-1)*sizeof(TextReplacementRule));
    }
    nrules--;
}

void rule_move_up(size_t index) {
    if(index == 0 || index >= nrules) {
        return;
    }
    TextReplacementRule tmp = rules[index-1];
    rules[index-1] = rules[index];
    rules[index] = tmp;
}

void rule_move_down(size_t index) {
    if(index+1 >= nrules) {
        return;
    }
    TextReplacementRule tmp = rules[index+1];
    rules[index+1] = rules[index];
    rules[index] = tmp;
}

int save_rules(const char *path) {
    FILE *out = fopen(path, "w");
    if(!out) {
        return 1;
    }
    
    fputs("?v1\n", out);
    for(int i=0;i<nrules;i++) {
        TextReplacementRule *rule = &rules[i];
        if(rule->pattern && strlen(rule->pattern) > 0) {
            fprintf(out, "%s\t%s\n", rule->pattern, rule->replacement);
        }
    }
    
    fclose(out);
    return 0;
}

size_t add_empty_rule(void) {
    nrules++;
    rules = realloc(rules, nrules * sizeof(TextReplacementRule));
    memset(&rules[nrules-1], 0, sizeof(TextReplacementRule));
    return nrules;
}

void free_rules(TextReplacementRule *rules, size_t nelm) {
    for(size_t i=0;i<nelm;i++) {
        free(rules[i].pattern);
        free(rules[i].replacement);
        if(rules[i].compiled) {
            regfree(&rules[i].regex);
        }
    }
    free(rules);
}



char* str_unescape_and_replace(
        const char *in,
        const char *search,
        const char *replacement)
{
    size_t alloc = 1024;
    size_t pos = 0;
    char *newstr = malloc(alloc);
    
    size_t search_len = strlen(search);
    size_t replacement_len = strlen(replacement);
    
    int escaped = 0;
    int match = 0;
    char c;
    for(;(c = *in ) != '\0';in++) {
        int matchchar = 1;
        if(escaped) {
            switch(c) {
                case 'n': c = '\n'; break;
                case 't': c = '\t'; break;
                case 'r': c = '\r'; break;
                case '$': matchchar = 0; break; // don't match escaped $
            }
        } else if(!escaped && c == '\\') {
            escaped = 1;
            continue;
        }
        if(pos + match >= alloc) {
            alloc *= 2;
            newstr = realloc(newstr, alloc);
        }
        
        if(search_len > 0 && matchchar && c == search[match]) {
            match++;
            if(match == search_len) {
                if(pos + replacement_len + 1 >= alloc) {
                    alloc *= 2;
                    newstr = realloc(newstr, alloc);
                }
                memcpy(newstr + pos, replacement, replacement_len);
                pos += replacement_len;
                match = 0;
            }
        } else {
            if(match > 0) {
                // copy previously skipped characters
                memcpy(newstr + pos, in - match, match);
                pos += match;
            }
            match = 0;
            newstr[pos++] = c;
        }
        escaped = 0;
    }
    
    if(pos >= alloc) {
        alloc++;
        newstr = realloc(newstr, alloc);
    }
    newstr[pos] = '\0';
    
    return newstr;
}

char* apply_rule(char *msg_in, TextReplacementRule *rule) {
    size_t len = strlen(msg_in);
    char *in = msg_in;
    char *end = in+len;
    
    // find all occurences of the pattern
    size_t alloc = 0;
    size_t pos = 0;
    char *newstr = NULL;
    while(in < end) {
        regmatch_t matches[2];
        int ret = regexec(&rule->regex, in, 2, matches, 0);
        if(ret) {
            break;
        }
        
        // add anything before the match
        size_t cplen = matches[0].rm_so;
        if(cplen >= alloc) {
            alloc += cplen + 1024;
            newstr = realloc(newstr, alloc);
        }
        if(cplen > 0) {
            memcpy(newstr+pos, in, cplen);
            pos += cplen;
        }
        
        // replace matches[0] with replacement
        // if a capture group exists, adjust the replacement
        char *rpl = rule->replacement;
        if(matches[1].rm_so >= 0) {
            size_t cg_len = matches[1].rm_eo - matches[1].rm_so;
            char *capture_group = malloc(cg_len + 1);
            memcpy(capture_group, in+matches[1].rm_so, cg_len);
            capture_group[cg_len] = 0;
            rpl = str_unescape_and_replace(rule->replacement, "$1", capture_group);
            free(capture_group);
        }
        size_t rpl_len = strlen(rpl);
        
        if(pos + rpl_len >= alloc) {
            alloc += rpl_len + 1024;
            newstr = realloc(newstr, alloc);
        }
        memcpy(newstr + pos, rpl, rpl_len);
        pos += rpl_len;
        if(rpl != rule->replacement) {
            free(rpl); // rpl was allocated by str_replace
        }
        
        in = in + matches[0].rm_eo;
    }
    
    // if no match was found, we can return the original msg ptr
    if(!newstr) {
        return msg_in;
    }
    
    // add remaining str
    size_t remaining = end - in;
    if(pos + remaining >= alloc) {
        alloc += remaining + 1;
        newstr = realloc(newstr, alloc);
    }
    if(remaining > 0) {
        memcpy(newstr+pos, in, remaining);
        pos += remaining;
    }
    
    if(pos >= alloc) {
        alloc++;
        newstr = realloc(newstr, alloc);
    }
    newstr[pos] = 0;
    
    free(msg_in);
    return newstr ? newstr : msg_in;
}

void apply_all_rules(char **msg) {
    char *msg_in = *msg;
    for(int i=0;i<nrules;i++) {
        if(rules[i].compiled) {
            msg_in = apply_rule(msg_in, &rules[i]);
        }
    }
    *msg = msg_in;
}
