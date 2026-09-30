#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

static const char *mode;
static const char *codex;
static int outcome = 1;
static void *worker(void *unused) {
    (void)unused;
    pid_t child;
    int control[2] = {-1, -1};
    printf("START: %s from pthread, pid=%d\n", mode, getpid());
    fflush(stdout);
    if (strcmp(mode, "fork") == 0) {
        pid_t parent = getpid();
        child = fork();
        if (child == 0) {
            if (setsid() == -1) _exit(120);
            if (prctl(PR_SET_PDEATHSIG, SIGTERM) == -1) {
                if (errno != EINVAL) _exit(121);
            } else if (getppid() != parent) {
                _exit(122);
            }
            execl("/bin/sh", "sh", "-c", "printf 'ish-shell-ok\\n'; exit 17", NULL);
            _exit(127);
        }
        if (child < 0) { perror("fork"); return NULL; }
    } else {
        posix_spawnattr_t attrs;
        posix_spawn_file_actions_t actions;
        posix_spawnattr_init(&attrs);
        posix_spawn_file_actions_init(&actions);
        sigset_t defaults;
        sigemptyset(&defaults);
        sigaddset(&defaults, SIGPIPE);
        posix_spawnattr_setsigdefault(&attrs, &defaults);
        posix_spawnattr_setflags(&attrs, POSIX_SPAWN_SETSIGDEF);
        char *env[] = {"PATH=/usr/bin:/bin", NULL};
        char *empty_env[] = {NULL};
        char *shell[] = {"sh", "-c", "printf 'ish-shell-ok\\n'; exit 17", NULL};
        char fd_arg[24], pid_arg[24];
        char *helper[] = {(char *)codex, "--codex-run-as-process-setup", fd_arg,
                          pid_arg, "pipe", "", "/", "/bin/sh", "sh", "-c",
                          "printf 'ish-shell-ok\\n'; exit 17", NULL};
        int is_helper = strcmp(mode, "helper") == 0;
        if (is_helper) {
            if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, control)) {
                perror("socketpair"); return NULL;
            }
            snprintf(fd_arg, sizeof(fd_arg), "%d", control[1]);
            snprintf(pid_arg, sizeof(pid_arg), "%d", getpid());
            posix_spawn_file_actions_adddup2(&actions, control[1], control[1]);
        }
        int error = posix_spawn(&child, is_helper ? codex : "/bin/sh",
                               &actions, &attrs, is_helper ? helper : shell,
                               is_helper ? empty_env : env);
        posix_spawnattr_destroy(&attrs);
        posix_spawn_file_actions_destroy(&actions);
        if (error) { fprintf(stderr, "posix_spawn: %s\n", strerror(error)); return NULL; }
        if (is_helper) {
            close(control[1]);
            const unsigned char size[4] = {0};
            if (write(control[0], size, sizeof(size)) != sizeof(size)) {
                perror("write environment"); return NULL;
            }
            unsigned char report[6];
            ssize_t count, total = 0;
            while (total < sizeof(report) && (count = read(control[0], report + total, sizeof(report) - total)) > 0)
                total += count;
            close(control[0]);
            printf("helper report bytes=%zd first=%d\n", total, total ? report[0] : -1);
            if (total != 1 || report[0] != 0) { kill(child, SIGKILL); waitpid(child, NULL, 0); return NULL; }
        }
    }
    int status;
    if (waitpid(child, &status, 0) == -1) { perror("waitpid"); return NULL; }
    printf("RESULT: %s raw_status=%d exit=%d signal=%d\n", mode, status,
           WIFEXITED(status) ? WEXITSTATUS(status) : -1,
           WIFSIGNALED(status) ? WTERMSIG(status) : 0);
    outcome = !(WIFEXITED(status) && WEXITSTATUS(status) == 17);
    return NULL;
}
int main(int argc, char **argv) {
    if (argc != 3) { fprintf(stderr, "usage: probe fork|posix|helper /path/to/codex\n"); return 2; }
    mode = argv[1]; codex = argv[2];
    if (strcmp(mode, "fork") && strcmp(mode, "posix") && strcmp(mode, "helper")) return 2;
    signal(SIGPIPE, SIG_IGN);
    pthread_t thread;
    int error = pthread_create(&thread, NULL, worker, NULL);
    if (error) { fprintf(stderr, "pthread_create: %s\n", strerror(error)); return 1; }
    pthread_join(thread, NULL);
    return outcome;
}
