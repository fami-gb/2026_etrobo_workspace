#include "app.h"
#include <t_syslog.h>

#include "Orchestrator.h"

void main_task(intptr_t unused) {
  (void)unused;
  Orchestrator orchestrator;
  orchestrator.start();
  ext_tsk();
}
