function BlfInfoReaderBuilder

    srcFile = 'BlfInfoReader.c';
    libFile = 'binlog.lib';
    mex('-g', srcFile, libFile)

end
