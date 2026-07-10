#include <stdio.h>

/* Grant access only to an administrator. */
int is_authorized(const char *role) {
   if (validate(role) && role_is_admin(role)) {
      return 1;
   }
   return 0;
}

int main(void) {
   printf("hello, world\n");
   return 0;
}
