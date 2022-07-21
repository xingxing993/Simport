
#include "mex.h"
#include <tchar.h>
#include <stdio.h>
#include <windows.h>
#include "binlog.h"
#include <math.h> 
#define STRICT
#define NUMBER_OF_FIELDS (sizeof(field_names) / sizeof(*field_names))

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    // declaration
    const char* field_names[] = {"Year", "Month", "Day", "Hour", "Minute" ,"Second", "Milliseconds"};
    mwSize dims[2] = {1, 2};
    mxArray* field_value;
    HANDLE hFile;
    VBLFileStatisticsEx statistics = { sizeof( statistics)};
    LPCTSTR pFileName;
    char *filetoread;
    size_t filenamelen;
    int filestatus;

    // filename
    filenamelen = mxGetN(prhs[0])*sizeof(mxChar)+1;
    filetoread = mxMalloc(filenamelen);
    filestatus = mxGetString(prhs[0], filetoread, (mwSize)filenamelen);   
    pFileName = filetoread;

    // binlog
    hFile = BLCreateFile( pFileName, GENERIC_READ);
    if(INVALID_HANDLE_VALUE != hFile)
    {
        BLGetFileStatisticsEx( hFile, &statistics);
        BLCloseHandle(hFile);
    }

    // plhs
    plhs[0] = mxCreateStructArray(2, dims, NUMBER_OF_FIELDS, field_names);

    // some ugly code for struct time info
    if(INVALID_HANDLE_VALUE != hFile)
    {
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wYear;
        mxSetFieldByNumber(plhs[0], 0, 0, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wMonth;
        mxSetFieldByNumber(plhs[0], 0, 1, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wDay;
        mxSetFieldByNumber(plhs[0], 0, 2, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wHour;
        mxSetFieldByNumber(plhs[0], 0, 3, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wMinute;
        mxSetFieldByNumber(plhs[0], 0, 4, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wSecond;
        mxSetFieldByNumber(plhs[0], 0, 5, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mMeasurementStartTime.wMilliseconds;
        mxSetFieldByNumber(plhs[0], 0, 6, field_value);

        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wYear;
        mxSetFieldByNumber(plhs[0], 1, 0, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wMonth;
        mxSetFieldByNumber(plhs[0], 1, 1, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wDay;
        mxSetFieldByNumber(plhs[0], 1, 2, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wHour;
        mxSetFieldByNumber(plhs[0], 1, 3, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wMinute;
        mxSetFieldByNumber(plhs[0], 1, 4, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wSecond;
        mxSetFieldByNumber(plhs[0], 1, 5, field_value);
        field_value = mxCreateDoubleMatrix(1, 1, mxREAL);
        *mxGetPr(field_value) = (double)statistics.mLastObjectTime.wMilliseconds;
        mxSetFieldByNumber(plhs[0], 1, 6, field_value);
    }
    // free
    mxFree(filetoread);
}