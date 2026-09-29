#define _GNU_SOURCE
#include <dlfcn.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

static __thread int in_resolve = 0;

static int ci_resolve_path(const char *path, char *out, size_t n) {
    if (!path || !*path) return 0;
    char work[PATH_MAX];
    if (path[0]=='/') {
        if (strlen(path)>=sizeof(work)) return 0;
        strcpy(work,path);
    } else {
        if (!getcwd(work,sizeof(work))) return 0;
        size_t l=strlen(work);
        if (l+1+strlen(path)+1>=sizeof(work)) return 0;
        if (l && work[l-1]!='/') strcat(work,"/");
        strcat(work,path);
    }
    char tmp[PATH_MAX]; strcpy(tmp,work);
    char cur[PATH_MAX]="/";
    char *save=NULL;
    for (char *tok=strtok_r(tmp,"/",&save); tok; tok=strtok_r(NULL,"/",&save)) {
        if (!strcmp(tok,".")) continue;
        if (!strcmp(tok,"..")) {
            size_t l=strlen(cur);
            if (l>1) {
                if (cur[l-1]=='/') cur[--l]=0;
                char *s=strrchr(cur,'/');
                if (s && s!=cur) *s=0; else strcpy(cur,"/");
            }
            continue;
        }
        char exact[PATH_MAX];
        snprintf(exact,sizeof(exact),"%s%s%s",cur, strcmp(cur,"/")?"/":"", tok);
        struct stat st;
        if (lstat(exact,&st)==0) {
            strncpy(cur,exact,sizeof(cur)-1); cur[sizeof(cur)-1]=0; continue;
        }
        DIR *d=opendir(cur);
        if (!d) return 0;
        char match[NAME_MAX+1]=""; int count=0;
        struct dirent *de;
        while ((de=readdir(d))) {
            if (!strcasecmp(de->d_name,tok)) { strncpy(match,de->d_name,NAME_MAX); match[NAME_MAX]=0; count++; if(count==1){} }
        }
        closedir(d);
        if (count<1) return 0;
        snprintf(exact,sizeof(exact),"%s%s%s",cur, strcmp(cur,"/")?"/":"", match);
        strncpy(cur,exact,sizeof(cur)-1); cur[sizeof(cur)-1]=0;
    }
    if (strlen(cur)+1>n) return 0;
    strcpy(out,cur); return 1;
}

static int resolve_if_missing(const char *path, char *out, size_t n) {
    if (in_resolve) return 0;
    in_resolve=1;
    int ok=ci_resolve_path(path,out,n);
    in_resolve=0;
    return ok;
}

typedef int (*open_fn)(const char*,int,...);
int open(const char *path, int flags, ...) {
    static open_fn real=NULL; if(!real) real=(open_fn)dlsym(RTLD_NEXT,"open");
    mode_t mode=0; if(flags&O_CREAT){va_list ap;va_start(ap,flags);mode=va_arg(ap,int);va_end(ap);} 
    int r=(flags&O_CREAT)?real(path,flags,mode):real(path,flags);
    if(r>=0 || errno!=ENOENT || in_resolve) return r;
    char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return (flags&O_CREAT)?real(alt,flags,mode):real(alt,flags);
    return r;
}
int open64(const char *path, int flags, ...) {
    static open_fn real=NULL; if(!real) real=(open_fn)dlsym(RTLD_NEXT,"open64");
    mode_t mode=0; if(flags&O_CREAT){va_list ap;va_start(ap,flags);mode=va_arg(ap,int);va_end(ap);} 
    int r=(flags&O_CREAT)?real(path,flags,mode):real(path,flags);
    if(r>=0 || errno!=ENOENT || in_resolve) return r;
    char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return (flags&O_CREAT)?real(alt,flags,mode):real(alt,flags);
    return r;
}

typedef FILE* (*fopen_fn)(const char*,const char*);
FILE *fopen(const char *path,const char *mode){
    static fopen_fn real=NULL; if(!real) real=(fopen_fn)dlsym(RTLD_NEXT,"fopen");
    FILE *r=real(path,mode); if(r||errno!=ENOENT||in_resolve) return r;
    char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return real(alt,mode); return r;
}
FILE *fopen64(const char *path,const char *mode){
    static fopen_fn real=NULL; if(!real) real=(fopen_fn)dlsym(RTLD_NEXT,"fopen64");
    FILE *r=real(path,mode); if(r||errno!=ENOENT||in_resolve) return r;
    char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return real(alt,mode); return r;
}

typedef int (*stat_fn)(const char*,struct stat*);
int stat(const char *path, struct stat *st){
 static stat_fn real=NULL; if(!real) real=(stat_fn)dlsym(RTLD_NEXT,"stat"); int r=real(path,st); if(!r||errno!=ENOENT||in_resolve)return r; char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return real(alt,st); return r; }
int lstat(const char *path, struct stat *st){
 static stat_fn real=NULL; if(!real) real=(stat_fn)dlsym(RTLD_NEXT,"lstat"); int r=real(path,st); if(!r||errno!=ENOENT||in_resolve)return r; char alt[PATH_MAX]; if(resolve_if_missing(path,alt,sizeof(alt))) return real(alt,st); return r; }
