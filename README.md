# fhem-apsystems-ecu

This is an experimental integration Module for the APSystems ECU into FHEM.

The work is based on https://github.com/ksheumaker/homeassistant-apsystems_ecur

## How to install
Copy [70_APSystemsECU.pm](70_APSystemsECU.pm) into your FHEM module folder and restart FHEM.

To create the device in FHEM run "define \<name\> APSystemsECU \<host\>  \<port\>".

![screenshot-fhem-ecu](https://github.com/benjamin-garn/fhem-apsystems-ecu/assets/3677978/eaf37494-5ae6-4f51-b3e3-2f095acdc0c5)

FTUI Integration:

![grafik](https://github.com/benjamin-garn/fhem-apsystems-ecu/assets/3677978/edf8eae9-ed0b-40a2-a655-ad0c4e0851e1)

```html
       <div class="cell">
            <div data-type="progress"
               data-device="ecu"
               data-get="LastSystemPower"
               data-min="0"
               data-max="700"
               data-unit=" W"
               class=""></div>
            <div data-type="label" data-device="ecu" data-get="CurrentDayEnergy" data-unit=" kWh" class="big inline left-space"></div>
            <div data-type="label">Balkonkraftwerk</div>
        </div>
```
## Technical Details

For the time beeing, the FHEM module does only provide LastSystemPower, CurrentDayEnergy and LifeTimeEnergy. It was tested with ECU-B.
By default they are fetched every 60 seconds from the ECU. The ECU itself updates them every 5 minutes.

For further development, I provided [test-ecu.pl](test-ecu.pl). It will display all the available readouts from ECU.

