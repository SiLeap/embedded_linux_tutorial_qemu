// hello.c - 交叉编译验证测试程序
#include <stdio.h>
#include <sys/utsname.h>

int main(void)
{
    struct utsname info;
    printf("Hello from cross-compiled binary!\n");
    if (uname(&info) == 0) {
        printf("Kernel : %s %s\n", info.sysname, info.release);
        printf("Machine: %s\n", info.machine);
    }
    return 0;
}
