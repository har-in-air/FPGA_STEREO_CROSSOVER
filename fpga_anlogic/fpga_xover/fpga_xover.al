<?xml version="1.0" encoding="UTF-8"?>
<Project>
    <Project_Created_Time>2020-09-24 08:14:23</Project_Created_Time>
    <TD_Version>4.6.14314</TD_Version>
    <UCode>01010110</UCode>
    <Name>fpga_xover</Name>
    <HardWare>
        <Family>EG4</Family>
        <Device>EG4S20BG256</Device>
    </HardWare>
    <Source_Files>
        <Verilog>
            <File>../xover_iir.v</File>
            <File>../audiosystem.v</File>
            <File>../i2s_rxtx_slave.v</File>
            <File>../load_coeffs.v</File>
            <File>../spi_slave.v</File>
            <File>../top.v</File>
            <File>../dpram.v</File>
        </Verilog>
        <ADC_FILE>fpga_xover.adc</ADC_FILE>
        <SDC_FILE>fpga_xover.sdc</SDC_FILE>
        <CWC_FILE/>
    </Source_Files>
    <TOP_MODULE>
        <LABEL/>
        <MODULE>top</MODULE>
        <CREATEINDEX>user</CREATEINDEX>
    </TOP_MODULE>
    <Project_Settings>
        <Step_Last_Change>2020-10-25 09:16:06</Step_Last_Change>
        <Current_Step>60</Current_Step>
        <Step_Status>true</Step_Status>
    </Project_Settings>
</Project>
