//библиотеки
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>

//буфер
#define BUF 256

//Цвета буфер
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define CYAN    "\033[36m"


int remove_recursive(const char *path);

//переменние
int lang_mode = 1;
int warnings = 1;
FILE *log_file = NULL;

char input[BUF];
char arg1[BUF];
char arg2[BUF];

//параметри

//лог
void trim_newline(char *s) {
    s[strcspn(s, "\n")] = 0;
}

//принт колор
void print_color(const char *ru, const char *en, const char *color) {
    printf("%s%s%s", color, (lang_mode == 0 ? ru : en), RESET);
}

//обичний принт
void print(const char *ru, const char *en) {
    printf("%s", lang_mode == 0 ? ru : en);
}

//Настройки
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

//распознавател аргументов
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

    *p2 = 0;
    snprintf(arg1, BUF, "%s", p + 1);
    snprintf(arg2, BUF, "%s", p2 + 1);
    trim_newline(arg2);
}

//Подтверждение об удаленние
int confirm() {
    if (!warnings) return 1;
    print_color("Вы уверены? (y/n): ", "Are you sure? (y/n): ", YELLOW);
    if (!fgets(input, BUF, stdin)) return 0;
    return input[0] == 'y';
}

//Лог
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

//хелп
void cmd_help() {
    print_color(
        "Команды: v ln lf md nf cd cf cpf m rf rd aw utw h q\n",
        "Commands: v ln lf md nf cd cf cpf m rf rd aw utw h q\n",
        YELLOW
    );
}

//lf
void cmd_ls() {
    DIR *d = opendir(".");
    if (!d) return;

    print_color("Содержимое папки:\n", "Folder content:\n", GREEN);

    struct dirent *f;
    while ((f = readdir(d))) {
        printf("%s\n", f->d_name);
    }
    closedir(d);
}

//md
void cmd_pwd() {
    char buf[512];
    if (!getcwd(buf, sizeof(buf))) {
        printf("%s", RED);
        perror("getcwd");
        printf("%s", RESET);
        log_error(strerror(errno));
        return;
    }
    printf("%s\n", buf);
}

//nf
void cmd_cd() {
    parse_one_arg();
    if (chdir(arg1) != 0) {
        printf("%s", RED);
        perror("chdir");
        printf("%s", RESET);
        log_error(strerror(errno));
    }
}

//cd
void cmd_mkdir() {
    parse_one_arg();
    if (mkdir(arg1, 0777) != 0) {
        printf("%s", RED);
        perror("mkdir");
        printf("%s", RESET);
        log_error(strerror(errno));
    }
}

//cf
void cmd_touch() {
    parse_one_arg();
    int fd = open(arg1, O_CREAT | O_WRONLY, 0666);
    if (fd < 0) {
        printf("%s", RED);
        perror("touch");
        printf("%s", RESET);
        log_error(strerror(errno));
        return;
    }
    close(fd);
}

//rf
void cmd_rm() {
    parse_one_arg();
    if (!confirm()) return;
    if (unlink(arg1) != 0) {
        printf("%s", RED);
        perror("unlink");
        printf("%s", RESET);
        log_error(strerror(errno));
    }
}

//remove
int remove_recursive(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) {
        printf("%s", RED);
        perror("lstat");
        printf("%s", RESET);
        log_error(strerror(errno));
        return -1;
    }

    if (!S_ISDIR(st.st_mode)) return unlink(path);

    DIR *dir = opendir(path);
    if (!dir) {
        printf("%s", RED);
        perror("opendir");
        printf("%s", RESET);
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

//rd
void cmd_rmdir() {
    parse_one_arg();
    if (!confirm()) {
        log_action("rmdir cancelled");
        return;
    }
    if (remove_recursive(arg1) != 0) {
        printf("%s", RED);
        perror("rmdir");
        printf("%s", RESET);
        log_error(strerror(errno));
    } else {
        print_color("Удалено\n", "Removed\n", GREEN);
        log_action("directory removed");
    }
}

//m
void cmd_mv() {
    parse_two_args();
    if (rename(arg1, arg2) != 0) {
        printf("%s", RED);
        perror("rename");
        printf("%s", RESET);
        log_error(strerror(errno));
    }
}

//cpf
void cmd_cp() {
    parse_two_args();

    struct stat st;
    if (stat(arg1, &st) != 0) {
        printf("%s", RED);
        perror("stat");
        printf("%s", RESET);
        log_error(strerror(errno));
        return;
    }

    int in = open(arg1, O_RDONLY);
    if (in < 0) {
        printf("%s", RED);
        perror("open src");
        printf("%s", RESET);
        log_error(strerror(errno));
        return;
    }

    int out = open(arg2, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);
    if (out < 0) {
        printf("%s", RED);
        perror("open dst");
        printf("%s", RESET);
        log_error(strerror(errno));
        close(in);
        return;
    }

    char buf[4096];
    ssize_t n;
    while ((n = read(in, buf, sizeof(buf))) > 0) {
        if (write(out, buf, n) != n) {
            printf("%s", RED);
            perror("write");
            printf("%s", RESET);
            log_error(strerror(errno));
            break;
        }
    }

    if (n < 0) {
        printf("%s", RED);
        perror("read");
        printf("%s", RESET);
        log_error(strerror(errno));
    }

    close(in);
    close(out);
}

//новости
void cmd_news() {
    print_color(
        "Нововведения v3\nДобавленния цветной подсветки\nизменен болшая техническая част коад что уменшаеть ошибки\n",
        "What's new v3\nAdded colors syntax\ncorrect tex wait C code do null error\n",
        YELLOW
    );
}

//main
int main() {
    if (geteuid() != 0) {
        printf(RED "Ошибка Запуска! возможние ошибки 1 устанвощик не правилно установил переустановите прогу 2 ви запускаетес без прав рут\n" RESET);
        return 1;
    }

    //пред вопросние функции
    load_settings();

    print_color(
    "Новая версия! v3 Введите 'n' чтобы узнать нововведения\n",
    "New version! v3 Type 'n' to see what's new\n",
    YELLOW
    );

    log_file = fopen("mft.log", "a");
    if (!log_file) perror("log file");

    while (1) {
    printf("%s%s%s",
        CYAN,
        (lang_mode == 0 ? "mft> " : "mft> "),
        RESET
    );

    if (!fgets(input, BUF, stdin)) break;
    trim_newline(input);
    log_action(input);

    if (strcmp(input, "v") == 0) {
        print_color("Версия MFT v3\n", "MFT Version v3\n", GREEN);
    } 
    else if (strcmp(input, "ln") == 0) {
        lang_mode ^= 1;
        save_settings();
    }

    else if (strcmp(input, "h") == 0) {
        cmd_help();
    }

    else if (strcmp(input, "lf") == 0) {
        cmd_ls();
    }

    else if (strcmp(input, "md") == 0) {
        cmd_pwd();
    }

    else if (strncmp(input, "nf ", 3) == 0) {
        cmd_cd();
    }

    else if (strncmp(input, "cd ", 3) == 0) {
        cmd_mkdir();
    }

    else if (strncmp(input, "cf ", 3) == 0) {
        cmd_touch();
    }

    else if (strncmp(input, "rf ", 3) == 0) {
        cmd_rm();
    }

    else if (strncmp(input, "rd ", 3) == 0) {
        cmd_rmdir();
    } 
    else if (strncmp(input, "m ", 2) == 0) {
        cmd_mv();
    }

    else if (strncmp(input, "cpf ", 4) == 0) {
        cmd_cp();
    }

    else if (strcmp(input, "aw") == 0) {
        warnings = 1;
        save_settings();
    }

    else if (strcmp(input, "utw") == 0) {
        warnings = 0;
        save_settings();
    }

    else if (strcmp(input, "n") == 0) {   
        cmd_news();
    }

    else if (strcmp(input, "q") == 0) {
        print("конец работи mft\n", "the end jab mft\n");
        break;
    }

    else {
        print_color("Ошибка\n", "Error\n", RED);
    }
    }

    //лог в вопросе
    if (log_file) {
        fprintf(log_file, "--- конец сесии ---\n");
        fclose(log_file);
    }

    return 0;
}