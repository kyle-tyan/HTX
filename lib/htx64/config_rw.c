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

/* @(#)66	1.2  src/htx/usr/lpp/htx/lib/misc64/config_rw.c, libmisc, htxubuntu 5/24/04 14:51:52 */

#include <stdio.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <linux/ioctl.h>
#include <asm/ioctl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include <sys/misclib.h>
/*#include<sys/mdio.h>*/

int ioctl_linux(char *str,int command, struct device_struct *dev_struct)
{
int rc;
FILE *fd;
		fd = open("/dev/miscchar", O_RDWR);
		if (fd < 0)
		{
		printf("\nerror opening file in user fn ioctl_linux\n");
		return -1;
		}
		/*printf("calling dev_struct bus=%d\n",dev_struct->bus_num);*/
		if(command == 0)
		rc = ioctl(fd, MIOPCFGET,dev_struct);
		/*printf("rc= %d\n",rc);*/
		close(fd);
		return rc;

}
