#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>

#define BUF 256

// --- Прототипы ---
int remove_recursive(const char *path);

// --- Глобальное состояние ---
int lang_mode = 1;        // 0 = RU, 1 = EN
int warnings = 1;         // 0 = no warning, 1 = warnings enabled
FILE *log_file = NULL;    // mft.log

char input[BUF];
char arg1[BUF];
char arg2[BUF];

// --- Утилиты ---
void trim_newline(char *s) {
    s[strcspn(s, "\n")] = 0;
}

void print(const char *ru, const char *en) {
    printf("%s", lang_mode == 0 ? ru : en);
}

// --- Настройки ---
void save_settings() {
    FILE *f = fopen("lang.txt", "wb");
    if (!f) return;
    fputc(lang_mode, f);
    fputc(warnings, f);
    fclose(f);
}

void load_settings() {
    FILE *f = fopen("lang.txt", "rb");
    if (!f) {
        lang_mode = 0;
        warnings = 1;
        return;
    }
    lang_mode = fgetc(f);
    warnings = fgetc(f);
    fclose(f);
}

// --- Парсинг аргументов ---
void parse_one_arg() {
    memset(arg1, 0, BUF);
    char *p = strchr(input, ' ');
    if (!p) return;
    snprintf(arg1, BUF, "%s", p + 1);
    trim_newline(arg1);
}

void parse_two_args() {
    memset(arg1, 0, BUF);
    memset(arg2, 0, BUF);

    char *p = strchr(input, ' ');
    if (!p) return;

    char *p2 = strchr(p + 1, ' ');
    if (!p2) return;

    *p2 = 0; // разделяем строки
    snprintf(arg1, BUF, "%s", p + 1);
    snprintf(arg2, BUF, "%s", p2 + 1);
    trim_newline(arg2);
}

// --- Подтверждение ---
int confirm() {
    if (!warnings) return 1;
    print("Вы уверены? (y/n): ", "Are you sure? (y/n): ");
    if (!fgets(input, BUF, stdin)) return 0;
    return input[0] == 'y';
}

// --- Логирование ---
void log_action(const char *action) {
    if (!log_file) return;
    fprintf(log_file, "[ACTION] %s\n", action);
    fflush(log_file);
}

void log_error(const char *msg) {
    if (!log_file) return;
    fprintf(log_file, "[ERROR] %s\n", msg);
    fflush(log_file);
}

// --- Команды ---
void cmd_help() {
    print(
        "Команды: v ln lf md nf cd cf cpf m rf rd aw utw h q\n",
        "Commands: v ln lf md nf cd cf cpf m rf rd aw utw h q\n"
    );
}

void cmd_ls() {
    DIR *d = opendir(".");
    if (!d) return;
    print("Содержимое папки:\n", "Folder content:\n");

    struct dirent *f;
    while ((f = readdir(d))) {
        printf("%s\n", f->d_name);
    }
    closedir(d);
}

void cmd_pwd() {
    char buf[512];
    if (!getcwd(buf, sizeof(buf))) {
        perror("getcwd");
        log_error(strerror(errno));
        return;
    }
    printf("%s\n", buf);
}

void cmd_cd() {
    parse_one_arg();
    if (chdir(arg1) != 0) {
        perror("chdir");
        log_error(strerror(errno));
    }
}

void cmd_mkdir() {
    parse_one_arg();
    if (mkdir(arg1, 0777) != 0) {
        perror("mkdir");
        log_error(strerror(errno));
    }
}

void cmd_touch() {
    parse_one_arg();
    int fd = open(arg1, O_CREAT | O_WRONLY, 0666);
    if (fd < 0) {
        perror("touch");
        log_error(strerror(errno));
        return;
    }
    close(fd);
}

void cmd_rm() {
    parse_one_arg();
    if (!confirm()) return;
    if (unlink(arg1) != 0) {
        perror("unlink");
        log_error(strerror(errno));
    }
}

int remove_recursive(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) {
        perror("lstat");
        log_error(strerror(errno));
        return -1;
    }

    if (!S_ISDIR(st.st_mode)) return unlink(path);

    DIR *dir = opendir(path);
    if (!dir) {
        perror("opendir");
        log_error(strerror(errno));
        return -1;
    }

    struct dirent *entry;
    char fullpath[512];

    while ((entry = readdir(dir))) {
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0)
            continue;
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);
        remove_recursive(fullpath);
    }

    closedir(dir);
    return rmdir(path);
}

void cmd_rmdir() {
    parse_one_arg();
    if (!confirm()) {
        log_action("rmdir cancelled");
        return;
    }
    if (remove_recursive(arg1) != 0) {
        perror("rmdir");
        log_error(strerror(errno));
    } else {
        log_action("directory removed");
    }
}

void cmd_mv() {
    parse_two_args();
    if (rename(arg1, arg2) != 0) {
        perror("rename");
        log_error(strerror(errno));
    }
}

void cmd_cp() {
    parse_two_args();

    struct stat st;
    if (stat(arg1, &st) != 0) {
        perror("stat");
        log_error(strerror(errno));
        return;
    }

    int in = open(arg1, O_RDONLY);
    if (in < 0) {
        perror("open src");
        log_error(strerror(errno));
        return;
    }

    int out = open(arg2, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);
    if (out < 0) {
        perror("open dst");
        log_error(strerror(errno));
        close(in);
        return;
    }

    char buf[4096];
    ssize_t n;
    while ((n = read(in, buf, sizeof(buf))) > 0) {
        if (write(out, buf, n) != n) {
            perror("write");
            log_error(strerror(errno));
            break;
        }
    }
    if (n < 0) {
        perror("read");
        log_error(strerror(errno));
    }

    close(in);
    close(out);
}

// --- Главный цикл ---
int main() {
    if (geteuid() != 0) {
        printf("Run as sudo!\n");
        return 1;
    }

    load_settings();

    log_file = fopen("mft.log", "a");
    if (!log_file) perror("log file");

    while (1) {
        printf("%s", lang_mode == 0 ? "mft> " : "mft_en> ");
        if (!fgets(input, BUF, stdin)) break;
        trim_newline(input);
        log_action(input);

        if (strcmp(input, "v") == 0) {
            printf("MFT Version v2\n");
        } else if (strcmp(input, "ln") == 0) {
            lang_mode ^= 1;
            save_settings();
        } else if (strcmp(input, "h") == 0) {
            cmd_help();
        } else if (strcmp(input, "lf") == 0) {
            cmd_ls();
        } else if (strcmp(input, "md") == 0) {
            cmd_pwd();
        } else if (strncmp(input, "nf ", 3) == 0) {
            cmd_cd();
        } else if (strncmp(input, "cd ", 3) == 0) {
            cmd_mkdir();
        } else if (strncmp(input, "cf ", 3) == 0) {
            cmd_touch();
        } else if (strncmp(input, "rf ", 3) == 0) {
            cmd_rm();
        } else if (strncmp(input, "rd ", 3) == 0) {
            cmd_rmdir();
        } else if (strncmp(input, "m ", 2) == 0) {
            cmd_mv();
        } else if (strncmp(input, "cpf ", 4) == 0) {
            cmd_cp();
        } else if (strcmp(input, "aw") == 0) {
            warnings = 1;
            save_settings();
        } else if (strcmp(input, "utw") == 0) {
            warnings = 0;
            save_settings();
        } else if (strcmp(input, "q") == 0) {
            break;
        } else {
            print("Ошибка\n", "Error\n");
        }
    }

    if (log_file) {
        fprintf(log_file, "--- session end ---\n");
        fclose(log_file);
    }

    return 0;
}