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

/* @(#)86	1.5  src/htx/usr/lpp/htx/lib/cfgc/cfgcclsf.c, htx_libcfgc, htxubuntu 5/24/04 17:59:25 */

/********************************************************************/
/*                                                                  */
/* Module Name:  cfgcclsf                                           */
/* Component Name:  CFG - System Configuration                      */
/* LPP Name:  BOS                                                   */
/*                                                                  */
/* Descriptive Name:  Attribute File Close Routine                  */
/*                                                                  */
/* Function:  This routine will close an attribute file which was   */
/*      opened by cfgcopsf.  It then frees the space occupied by    */
/*      the attribute file pointer structure.                       */
/*                                                                  */
/* Compiler Options:                                                */
/*      -DBUG turns on debug print statements                       */
/*                                                                  */
/* Input:                                                           */
/*      sfptr  - pointer to the attribute file pointer structure    */
/*                                                                  */
/* Output:  none                                                    */
/*                                                                  */
/* Normal Return:  CFG_SUCC                                         */
/*                                                                  */
/* Error Return:                                                    */
/*      I/O error from fclose                                       */
/*                                                                  */
/* External References:                                             */
/*                                                                  */
/*   Other Routines:                                                */
/*      fclose(3)                                                   */
/*      free(3)                                                     */
/*                                                                  */
/*   Data Areas:                                                    */
/*                                                                  */
/* Change Activity:                                                 */
/*                                                                  */
/********************************************************************/

#include <cfgclib.h>
#include <cfgcom.h>
#include <cfgpest.h>

int	cfgcclsf(CFG__SFT *sfptr)
{
    	int	rc = CFG_SUCC;

    	buglrt(BUGNTF,"entry",*sfptr,X);
	/*
	 * close the file
	 */
    	rc = fclose(sfptr->sfile);

    	buglpr(BUGNFO,("File %s closed, return code = %d.\n",sfptr->spath,rc));

    	if (rc != 0) {			/* if error returned */
		rc = CFG_UNIO;		/* set standard return code */
		htx_strcpy(msgc2,sfptr->spath);	/* set global message insert */
    	}

    	if (sfptr->defbuf != NULL) {        /* free allocated storage       */
		free(sfptr->defbuf);
		free(sfptr->defmap);
    	}

    	free(sfptr);
    	buglrt(BUGNTF,"exit",rc,d);

    	return(rc);
}


