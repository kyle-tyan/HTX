/* @(#)49	1.8  src/htx/usr/lpp/htx/bin/htxd/htxd_instance.h, htxd, htxubuntu 11/24/15 23:59:23 */



#ifndef HTXD__INSTANCE__HEADER
#define HTXD__INSTANCE__HEADER

#include "htxd.h"


extern int			htxd_is_profile_initialized(htxd *);
extern htxd *			htxd_create_instance(void);
extern void			init_htxd_instance(htxd *);
extern htxd *			htxd_get_instance(void);
extern void			htxd_init_instance(htxd *);
extern int			htxd_is_daemon_idle(void);
extern int			htxd_is_daemon_selected(void);
extern void			htxd_set_daemon_idle(void);
extern int			htxd_get_daemon_state(void);
extern void			htxd_set_daemon_state(int);
extern void			htxd_set_htx_msg_pid(pid_t);
extern pid_t			htxd_get_htx_msg_pid(void);
extern void			htxd_set_htx_stats_pid(pid_t);
extern pid_t			htxd_get_htx_stats_pid(void);
extern void			htxd_set_dr_child_pid(pid_t);
extern pid_t			htxd_get_dr_child_pid(void);
extern texer_list *		htxd_get_exer_table(void);
extern int			htxd_get_exer_table_length(void);
extern int			htxd_reset_exer_pid(pid_t, char *);
extern void			htxd_display_exer_table(void);
extern int			htxd_update_command_object(char *);
extern int			htxd_get_command_index(void);
extern char *			htxd_get_command_ecg_name(void);
extern void			htxd_set_command_ecg_name(char *);
extern char *			htxd_get_command_option_list(void);
extern htxd_ecg_manager *	htxd_get_ecg_manager(void);
void				htxd_set_ecg_manager(htxd_ecg_manager *);
void				htxd_delete_ecg_manager(void);
extern int			htxd_get_dr_sem_key(void);
extern void			htxd_set_dr_sem_id(int new_dr_sem_id);
extern int			htxd_get_dr_sem_id(void);
extern int			htxd_get_dr_reconfig_restart(void);
extern void			htxd_set_dr_reconfig_restart(int value);
extern void			htxd_set_htx_path(char *);
extern char *			htxd_get_htx_path(void);
extern int			htxd_get_msg_queue_id(void);
extern void			htxd_set_program_name(char *);
extern char *			htxd_get_program_name(void);
extern int			htxd_get_number_of_running_ecg(void);  /* not using now */
extern void			htxd_set_equaliser_pid(int);
extern pid_t			htxd_get_equaliser_pid(void);
extern void			htxd_set_equaliser_shm_addr(union shm_pointers);
extern union shm_pointers	htxd_get_equaliser_shm_addr(void);
extern void			htxd_set_equaliser_semhe_id(int);
extern int			htxd_get_equaliser_semhe_id(void);
extern void			htxd_set_equaliser_conf_file(char *);
extern char *			htxd_get_equaliser_conf_file(void);
extern void			htxd_set_equaliser_debug_flag(int);
extern int			htxd_get_equaliser_debug_flag(void);
extern int			htxd_is_hang_monitor_initialized(void);
extern void			htxd_remove_hang_monitor(void);
extern int			htxd_is_hotplug_monitor_initialized(void);
extern void			htxd_remove_hotplug_monitor(void);
extern void			htxd_set_system_header_info_shm_id(int);
extern int			htxd_get_system_header_info_shm_id(void);
extern void			htxd_set_exer_table_shm_id(int);
extern int			htxd_get_exer_table_shm_id(void);
extern tsys_hdr *		htxd_get_system_header_info(void);
extern void			htxd_set_init_syscfg_flag(int);
extern int			htxd_is_init_syscfg(void);

#endif