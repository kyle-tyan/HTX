/* IBM_PROLOG_BEGIN_TAG */
/* 
 * Copyright 2003,2016 IBM International Business Machines Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * 		 http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/* IBM_PROLOG_END_TAG */
/* @(#)72	1.7  src/htx/usr/lpp/htx/bin/htxd/htxd_util.c, htxd, htxubuntu 9/15/15 20:28:41 */



#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <htxd_common_define.h>
#include <hxihtx.h>
#include "htxd_define.h"
#include "htxd_trace.h"

#include "htxd_instance.h"
#include <hxiipc.h>






void htxd_correct_device_list_for_all_devices(char *device_name_list)
{
	char *p_device_name;
	char temp_device_name_list[MAX_OPTION_LIST_LENGTH];

	if(strlen(device_name_list) > 0) {
		strcpy(temp_device_name_list, device_name_list);
		p_device_name = strtok(temp_device_name_list, " ");

		while(p_device_name != NULL) {
			if(strcmp(p_device_name, "all") == 0) {
				device_name_list[0] = '\0';
			}

			p_device_name = strtok(NULL, " ");
		}
	}
}



int htxd_is_all_device_found(char *device_name_list)
{
	char *p_device_name;
	char temp_device_name_list[MAX_OPTION_LIST_LENGTH];

	strcpy(temp_device_name_list, device_name_list);

	p_device_name = strtok(temp_device_name_list, " ");

	while(p_device_name != NULL) {
		if(strcmp(p_device_name, "all") == 0) {
			return TRUE;
		}

		p_device_name = strtok(NULL, " ");
	}

	return FALSE;
}



int htxd_get_time_details(time_t epoch_time, char *formatted_date, char *day_of_year, char *formatted_time)
{
	struct tm time_var;
	int year2000;

	if(epoch_time == -1) {
		if(formatted_date != NULL) {
			sprintf(formatted_date, "00/00/00");
		}
		if(day_of_year != NULL) {
			sprintf(day_of_year, "000");
		}
		if(formatted_time != NULL) {
			sprintf(formatted_time, "00:00:00");
		}
		return 0;
	}

	localtime_r (&epoch_time, &time_var);

	if(time_var.tm_year > 99) {
		year2000 = time_var.tm_year - 100;
	} else {
		year2000 = time_var.tm_year;
	}

	if(formatted_date != NULL) {
		sprintf(formatted_date, "%.2d/%.2d/%.2d", (time_var.tm_mon + 1), time_var.tm_mday, year2000);
	}
	if(day_of_year != NULL) {
		sprintf(day_of_year, "%.3d", (time_var.tm_yday + 1));
	}
	if(formatted_time != NULL) {
		sprintf(formatted_time, "%.2d:%.2d:%.2d", time_var.tm_hour, time_var.tm_min, time_var.tm_sec);
	}

	return 0;
}




int htxd_is_file_exist(char *filename)
{
	struct stat file_status;
	char trace_string[256];
	int return_code;


	return_code = stat(filename, &file_status);
	if( return_code == 0) {
		return TRUE;
	}

	sprintf(trace_string, "stat() failed at htxd_is_file_exist with return value = <%d>, errno = <%d>, filename <%s>, return", return_code, errno, filename);
	HTXD_TRACE(LOG_OFF, trace_string);
	return FALSE;
}



char *htxd_unquote(char *s)
{
	char t[100], *t_ptr = t, *s_save = s;

	do {
		if (*s != '\"') {
			*t_ptr = *s;
			t_ptr++;
		}
		s++;
	} while (*(s - 1) != '\0');

	s = s_save;
	t_ptr = t;

	while ((*s = *t_ptr) != '\0') {
		s++;
		t_ptr++;
	} /* end while */

	return(s_save);
}


void htxd_set_FD_close_on_exec_flag(void)
{
	fcntl(fileno(stdin), F_SETFD, FD_CLOEXEC);
	fcntl(fileno(stdout), F_SETFD, FD_CLOEXEC);
	fcntl(fileno(stderr), F_SETFD, FD_CLOEXEC);
}



void htxd_reset_FD_close_on_exec_flag(void)
{
	fcntl(fileno(stdin), F_SETFD, 0);
	fcntl(fileno(stdout), F_SETFD, 0);
	fcntl(fileno(stderr), F_SETFD, 0);
}



void htxd_set_value_FD_close_on_exec_flag(int value)
{
	fcntl(fileno(stdin), F_SETFD, value);
	fcntl(fileno(stdout), F_SETFD, value);
	fcntl(fileno(stderr), F_SETFD, value);
}



pid_t htxd_create_child_process(void)
{
	pid_t new_pid;

	htxd_set_FD_close_on_exec_flag();
	new_pid = fork();

	return new_pid;
}



/* read bytes from filename and create a read_buffer and store the bytes */
int htxd_read_file(char *filename, char **read_buffer)
{
	int read_file_fd;
	int return_code;
	struct stat read_file_stat;
	int size_of_read_buffer;
	int number_of_byes_read;
	char trace_string[256];


	*read_buffer = 0;

	return_code = stat(filename, &read_file_stat);
	if(return_code == -1 ) {
		sprintf(trace_string, "Error : htxd_read_file() open() return  = <%d>,  errno  = <%d>, filename = <%s>\n", return_code, errno, filename);
		HTXD_TRACE(LOG_ON, trace_string);
		return -1;
	}

	read_file_fd = open(filename, O_RDONLY);
	if(read_file_fd == -1) {
		sprintf(trace_string, "Error : htxd_read_file() open() return  = <%d>,  errno  = <%d>, filename = <%s>\n", return_code, errno, filename);
		HTXD_TRACE(LOG_ON, trace_string);
		return -1;
	}

	size_of_read_buffer = read_file_stat.st_size + 1024;

	*read_buffer = malloc(size_of_read_buffer);
	if(*read_buffer == NULL) {
		sprintf(trace_string, "Error : htxd_read_file() malloc(%d) return NULL, errno  = <%d>, filename = <%s>\n", size_of_read_buffer, errno, filename);
		HTXD_TRACE(LOG_ON, trace_string);
		close(read_file_fd);
		return -1;
	}

	memset(*read_buffer, 0, size_of_read_buffer);

	number_of_byes_read = read(read_file_fd, *read_buffer, size_of_read_buffer - 1024);
	if(number_of_byes_read == -1) {
		sprintf(trace_string, "Error : htxd_read_file() read() return <%d>, errno <%d>, filename = <%s>\n", number_of_byes_read, errno, filename);
		HTXD_TRACE(LOG_ON, trace_string);
	}
	if(number_of_byes_read == 0) {
		sprintf(*read_buffer, "file <%s> is empty", filename);
	}

	close(read_file_fd);

	return 0;
}



int htxd_get_regular_file_count(char *path_name)
{
	int file_count = 0;
	DIR *p_dir;
	struct dirent * p_dir_entry;


	p_dir = opendir(path_name);
	if(p_dir == NULL) {
		perror("dir open failed");
		return -1;
	}

	while ( (p_dir_entry = readdir(p_dir) ) != NULL) {
		file_count++;
	}

	if(closedir(p_dir)) {
		perror("dir close failed");
		return -1;
	}
	return file_count;
}



int htxd_wrtie_mdt_list(char *mdt_dir, char *mdt_list_file, int mdt_count, char *write_mode, char *separator)
{
	FILE *p_file;
	DIR *p_dir;
	struct dirent * p_dir_entry;

	p_file = fopen(mdt_list_file, write_mode);
	if(p_file == NULL) {
		return -1;
	}

	p_dir = opendir(mdt_dir);
	if(p_dir == NULL) {
		perror("dir open failed");
		return -1;
	}
	if( (strcmp(write_mode, "w") == 0) || (strcmp(write_mode, "w+") == 0)) {
		fprintf(p_file, "Total ECG = %d\n", mdt_count);
	}

	while ( (p_dir_entry = readdir(p_dir) ) != NULL) {
		fprintf(p_file, "%s%s", p_dir_entry->d_name, separator);
	}

	if(closedir(p_dir)) {
		perror("dir close failed");
		return -1;
	}

	fclose(p_file);
	return 0;
}



short htxd_send_message(char *msg_text, int errno_val, int  severity, mtyp_t msg_type)
{
	int msgqid;
	time_t  system_time;
	char *str_time_ptr;
	char *program_name;
	char char_time[40];
	short exit_code = 0;
	int errno_save;
	char error_msg[512];
	struct htx_msg_buf msg_buffer;
	size_t str_length;


	msgqid = htxd_get_msg_queue_id();
/* 	printf("DEBUG: htxd_send_message()enter :  msgqid=<%d>\n", msgqid); */

	memset(&msg_buffer, 0, sizeof(msg_buffer) );

	if (msgqid != -1) {
		if (strlen(msg_text) > MAX_TEXT_MSG) {
			msg_text[MAX_TEXT_MSG] = '\0';
			exit_code |= MSG_TOO_LONG;
		}

		errno = 0;

		program_name = htxd_get_program_name();

#ifdef __HTX_LINUX__
		system_time = time((time_t *) NULL);
		str_time_ptr = ctime((const time_t *) &system_time);
		strncpy(char_time, "", sizeof(char_time));
		strncpy(char_time, (str_time_ptr + 4), 20);
#else
		system_time = time((time_t *) NULL);
		if(system_time ==0) {
			errno_save = errno;
			(void) sprintf(error_msg,"\n%s -- Error in the time() system call of the send_message() function.\nerrno: %d (%s).\n",program_name, errno_save, strerror(errno_save));
			fprintf(stderr, "%s", error_msg);
			fflush(stderr);
			exit_code |= BAD_GETTIMER;
			strcpy(char_time, "time() error");
		} else {
			str_time_ptr = ctime((time_t *) (&system_time));
			strncpy(char_time, "", sizeof(char_time));
			strncpy(char_time, (str_time_ptr + 4), 20);
		}
#endif


/*		strcpy(msg_buffer.htx_data.sdev_id, "htx_messages");
		msg_buffer.htx_data.error_code = errno_val;
		msg_buffer.htx_data.severity_code = severity;
		strcpy(msg_buffer.htx_data.HE_name, program_name);

*/


		strncpy(msg_buffer.htx_data.sdev_id, "", sizeof(msg_buffer.htx_data.sdev_id));
		strncpy(msg_buffer.htx_data.sdev_id, "htx_messages", (sizeof(msg_buffer.htx_data.sdev_id) - 1));
		msg_buffer.htx_data.error_code = errno_val;
		msg_buffer.htx_data.severity_code = severity;
		strncpy(msg_buffer.htx_data.HE_name, "", sizeof(msg_buffer.htx_data.HE_name));
		strncpy(msg_buffer.htx_data.HE_name, program_name, (sizeof(msg_buffer.htx_data.HE_name) - 1));

		sprintf(msg_buffer.htx_data.msg_text,"---------------------------------------------------------------------\nDevice id      : %-18s\nTimestamp      : %-20s\nerr            : %-8.8x\nsev            : %d\nExerciser Name : %-14s\nError Text     : %s\n---------------------------------------------------------------------\n",
			msg_buffer.htx_data.sdev_id,
			char_time,
			msg_buffer.htx_data.error_code,
			msg_buffer.htx_data.severity_code,
			msg_buffer.htx_data.HE_name,
			msg_text);

		str_length = strlen(msg_buffer.htx_data.msg_text);
		if (msg_buffer.htx_data.msg_text[str_length - 2] != '\n') {
			strcat(msg_buffer.htx_data.msg_text, "\n");
		}

		msg_buffer.mtype = msg_type;

		errno = 0;

		if (msgsnd(msgqid, &msg_buffer, (sizeof(msg_buffer) - sizeof(mtyp_t)), IPC_NOWAIT) != GOOD) {
			errno_save = errno;
			sprintf(error_msg, "\n%s -- Error in msgsnd() system call of the send_message() function.\nerrno: %d (%s).\n",
				program_name,
				errno_save,
				strerror(errno_save));

			fprintf(stderr, "%s", error_msg);
			fflush(stderr);
			exit_code |= BAD_MSGSND;
		}
	} else {
		fprintf(stderr, "%s", msg_text);
		fflush(stderr);
		exit_code |= NO_MSG_QUEUE;
	}

	return(exit_code);
}



int htxd_execute_shell_profile(void)
{
	int return_status;
	int return_code;
	char trace_string[256];


#ifdef  __HTX_LINUX__
	return_status = system("/bin/bash /usr/lpp/htx/.bash_profile > /tmp/htxd_bash_profile_output 2>&1");
#else
	return_status = system("/usr/lpp/htx/.profile > /tmp/htxd_bash_profile_output 2>&1");
#endif

	return_code = WEXITSTATUS(return_status);
	if(return_code != 0) {
		sprintf(trace_string, "shell profile execute returned with code <%d>, ignoring the return code", return_code);
		HTXD_TRACE(LOG_ON, trace_string);
		return_code = 0;
	}
	return return_code;
}


int htxd_truncate_error_file(void)
{
	int return_code;

	return_code = truncate(HTX_ERR_LOG_FILE, 0);

	return return_code;
}

#ifdef __HTX_LINUX__
/* Function binds a given TID  to any thread of core 0 */
int do_the_bind_proc(pid_t pid)
{
    int lcpu, rc = 0;

    lcpu = get_logical_cpu_num(0, 0, 0, bind_th_num); /* Bind to N0P0C0T* */
    rc = bind_process(pid, lcpu, -1);
    bind_th_num = (bind_th_num + 1) % smt;
    return rc;
}

/* Function binds a given TID  to any thread of core 0 */
int do_the_bind_thread(pthread_t tid)
{
    int lcpu, rc = 0;

    lcpu = get_logical_cpu_num(0, 0, 0, bind_th_num); /* Bind to N0P0C0T* */
    rc = bind_thread(tid, lcpu, -1);
    bind_th_num = (bind_th_num + 1) % smt;
    return rc;
}
#endif

