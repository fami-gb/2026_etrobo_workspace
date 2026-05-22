#include "app.h"
#include <t_syslog.h>

void main_task(intptr_t unused) {
  (void)unused;
  syslog(LOG_NOTICE, "Hello, ETRobo!");
  ext_tsk();
}
