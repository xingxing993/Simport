
#include "mex.h"
#include <tchar.h>                     /* RTL   */
#include <stdio.h>
#include <windows.h>
#include "binlog.h"                    /* BL    */
#include <math.h> 
#define STRICT                         /* WIN32 */

static BYTE dlcMapping[17] = {0,1,2,3,4,5,6,7,8,12,16,20,24,32,48,64};
int read_statistics(LPCTSTR pFileName, VBLFileStatisticsEx* pstatistics)
{
    HANDLE hFile;
    BOOL bSuccess;
    hFile = BLCreateFile( pFileName, GENERIC_READ);
    if ( INVALID_HANDLE_VALUE == hFile)
    {
        return -1;
    }
    BLGetFileStatisticsEx( hFile, pstatistics);
    if ( !BLCloseHandle( hFile))
    {
        return -1;
    }
    return bSuccess ? 0 : -1;
}



int read_info( LPCTSTR pFileName, LPDWORD pRead, double* candata_, double* canmsgid_, double* canchannel_, double* cantime_)
{
    HANDLE hFile;
    VBLObjectHeaderBase base;
    VBLCANMessage message;
    VBLCANMessage2 message2;
    VBLCANFDMessage64 messageFD;
    unsigned int i;

    BOOL bSuccess;

    if ( NULL == pRead)
    {
        return -1;
    }

    *pRead = 0;

    /* open file */
    hFile = BLCreateFile( pFileName, GENERIC_READ);

    if ( INVALID_HANDLE_VALUE == hFile)
    {
        return -1;
    }


    bSuccess = TRUE;
    
    /* read base object header from file */
    while ( bSuccess && BLPeekObject( hFile, &base))
    {
        switch ( base.mObjectType)
        {
        case BL_OBJ_TYPE_CAN_MESSAGE:
            /* read CAN message */
            message.mHeader.mBase = base;
            bSuccess = BLReadObjectSecure( hFile, &message.mHeader.mBase, sizeof(message));
            /* free memory for the CAN message */
            if( bSuccess) {
              for(i=0;i<8;i++) *(candata_ + (*pRead)*64 + i) = (double)message.mData[i];
              *(canmsgid_ + (*pRead)) = (double)message.mID;
              *(canchannel_ + (*pRead)) = (double)message.mChannel;
              if(message.mHeader.mObjectFlags==BL_OBJ_FLAG_TIME_ONE_NANS)
              	*(cantime_ + (*pRead)) = ((double)message.mHeader.mObjectTimeStamp)/1000000000;
              else
                *(cantime_ + (*pRead)) = ((double)message.mHeader.mObjectTimeStamp)/100000;
              BLFreeObject( hFile, &message.mHeader.mBase);
              *pRead += 1;
            }
            break;
        case BL_OBJ_TYPE_CAN_MESSAGE2:
            /* read CAN message */
            message2.mHeader.mBase = base;
            bSuccess = BLReadObjectSecure( hFile, &message2.mHeader.mBase, sizeof(message2));
            /* free memory for the CAN message */
            if( bSuccess) {
              for(i=0;i<8;i++) *(candata_ + (*pRead)*64 + i) = (double)message2.mData[i];
              *(canmsgid_ + (*pRead)) = (double)message2.mID;
              *(canchannel_ + (*pRead)) = (double)message2.mChannel;
              if(message2.mHeader.mObjectFlags==BL_OBJ_FLAG_TIME_ONE_NANS)
              	*(cantime_ + (*pRead)) = ((double)message2.mHeader.mObjectTimeStamp)/1000000000;
              else
                *(cantime_ + (*pRead)) = ((double)message2.mHeader.mObjectTimeStamp)/100000;
              BLFreeObject( hFile, &message2.mHeader.mBase);
              *pRead += 1;
            }
            break;
        case BL_OBJ_TYPE_CAN_FD_MESSAGE_64:
            messageFD.mHeader.mBase = base;
            bSuccess = BLReadObjectSecure( hFile, &messageFD.mHeader.mBase, sizeof(messageFD));
            if( bSuccess) {
                for(i=0;i<dlcMapping[messageFD.mDLC];i++) *(candata_ + (*pRead)*64 + i) = (double)messageFD.mData[i];
                *(canmsgid_ + (*pRead)) = (double)messageFD.mID;
                *(canchannel_ + (*pRead)) = (double)messageFD.mChannel;
                if(messageFD.mHeader.mObjectFlags==BL_OBJ_FLAG_TIME_ONE_NANS)
                *(cantime_ + (*pRead)) = ((double)messageFD.mHeader.mObjectTimeStamp)/1000000000;
                else
                *(cantime_ + (*pRead)) = ((double)messageFD.mHeader.mObjectTimeStamp)/100000;
                BLFreeObject( hFile, &messageFD.mHeader.mBase);
                *pRead += 1;
            }
            break;
        case BL_OBJ_TYPE_ENV_INTEGER:
        case BL_OBJ_TYPE_ENV_DOUBLE:
        case BL_OBJ_TYPE_ENV_STRING:
        case BL_OBJ_TYPE_ENV_DATA:
        case BL_OBJ_TYPE_ETHERNET_FRAME:
        case BL_OBJ_TYPE_APP_TEXT:
        default:
            /* skip all other objects */
            bSuccess = BLSkipObject( hFile, &base);
            break;
        }
        //mexPrintf("%s%u\n", "count: ", *pRead);
    }

    /* close file */
    if ( !BLCloseHandle( hFile))
    {
        return -1;
    }

    return bSuccess ? 0 : -1;
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    // define
    DWORD msgcnt;
    double *candata, *cantime, *canmsgid, *canchannel;
    LPCTSTR pFileName;
    char *filetoread;
    size_t filenamelen;
    int filestatus;
    double needmemorysize;
    double *PWin;
    double PW;
    double *pswitchFlag;
    unsigned char switchFlag = 0;
    
    int result_statistic, result_read;
    VBLFileStatisticsEx statistics = { sizeof( statistics)};
    
    // filename
    filenamelen = mxGetN(prhs[0])*sizeof(mxChar)+1;
    filetoread = mxMalloc(filenamelen);
    filestatus = mxGetString(prhs[0], filetoread, (mwSize)filenamelen);   
    pFileName = filetoread;
    
    // PW
    if (nrhs<2)
    {
        return;
    }else
    {
        PW = 789456.0F;
        PWin = mxGetPr(prhs[1]);
        if (!((*PWin - PW)<2))
        {
            return;
        }
    }
    if (nrhs==3)
    {
        pswitchFlag = mxGetPr(prhs[2]);
        switchFlag = (unsigned char)(*pswitchFlag);
    }

    // print author infos
    if(switchFlag!=1U)
    {
        char *blfversion ="1.3.0";
        mexPrintf("%s\n", "BlfLoad -- Loads a CANoe/CANalyzer Data file into a Matlab Structure.");
        mexPrintf("%s%s\t", "Version: ", blfversion);
        mexPrintf("%s\t%s\n\n", "by Shen, Chenghao", "snc6si@gmail.com");
    }
        mexPrintf("%s%s\n", "Loading File: ", pFileName);
    // read blf statistics to determine output matrix size
    result_statistic = 0;
    result_statistic = read_statistics( pFileName, &statistics);
    
    if(switchFlag!=1U)
    {
        //print statistics info
        mexPrintf("%s%u%s\n\n", "The blf file contains ", statistics.mObjectCount, " can(fd) messages");
        
        needmemorysize = ((double)statistics.mObjectCount)*(8+1+1+1)*8/1024/1024;
        //mexPrintf("%s%f%s\n", "This requires ", needmemorysize, " Mb Matlab Memory");
    }
    
    // plhs[0]: candata
    plhs[0] = mxCreateDoubleMatrix (64,statistics.mObjectCount , mxREAL);
    candata = mxGetPr(plhs[0]);
    
    // plhs[1]: canmsgid
    plhs[1] = mxCreateDoubleMatrix (1,statistics.mObjectCount , mxREAL);
    canmsgid = mxGetPr(plhs[1]);
    
    // plhs[2]: canchannel
    plhs[2] = mxCreateDoubleMatrix (1,statistics.mObjectCount , mxREAL);
    canchannel = mxGetPr(plhs[2]);
    
    // plhs[3]: camtime
    plhs[3] = mxCreateDoubleMatrix (1,statistics.mObjectCount , mxREAL);
    cantime = mxGetPr(plhs[3]);
    
    result_read = 0;
    result_read = read_info( pFileName, &msgcnt, candata, canmsgid, canchannel, cantime);
    
    mxSetN(plhs[0],msgcnt);
    mxSetN(plhs[1],msgcnt);
    mxSetN(plhs[2],msgcnt);
    mxSetN(plhs[3],msgcnt);
    
    // free filetoread, which is created using mxMalloc
    mxFree(filetoread);
}

