#!/bin/bash
#
# A script that helps you to select a different kernel to boot on your Ubuntu system.
# https://github.com/Cypresslin/alt_my_grub
#
#                              Author: Po-Hsu Lin <po-hsu.lin@canonical.com>
#				Modified by Dilan Patel to specifically select Kernel 5.10.0 and make process non-interactive, credits to original author

grubcfg="/boot/grub/grub.cfg"
grubfile="/etc/default/grub"
end_pattern="### END /etc/grub.d/30_os-prober ###"
one_time=false
desired_entry="Ubuntu, with Linux 5.10.0-051000-generic"

function filecheck {
    if [ ! -f $1 ]; then
        echo "$1 not found, please change the setting"
        exit 1
    fi
}

filecheck $grubcfg
filecheck $grubfile

# Find menuentries and submenu, unify the quote and extract the title
rawdata=`grep -e 'menuentry ' -e 'submenu ' "$grubcfg"`
output=`echo "$rawdata" |sed "s/'/\"/g" | cut -d '"' -f2`
# Get the line index of submenu
subidx=`echo "$rawdata" | grep -n 'submenu ' | awk -F':' '{print $1}'`
# The submenu will eventually ends before "### END /etc/grub.d/30_os-prober ###"
endidx=`grep -e "menuentry " -e "submenu " -e "$end_pattern" "$grubcfg" | grep -n "$end_pattern" | awk -F':' '{print $1}'`
endidx=$((endidx-1))

# Split results into array
IFS=' '
readarray -t entries <<<"$output"

idx=0
for entry in "${entries[@]}"
do
    if [ "$entry" == "$desired_entry" ]; then
        opt=$idx
        break
    fi
    idx=$((idx+1))
done

# Automated the selection for the desired entry
subidx=`echo $subidx | tr '\n' ' '`
menuid=""
for i in $subidx
do
    if [ $opt -gt $((i-1)) ] && [ $opt -lt $endidx ]; then
        menuid=$((i-1))
    fi
done
if [ ! -z "$menuid" ]; then
    target="'${entries[$menuid]}>${entries[$opt]}'"
else
    target="'${entries[$opt]}'"
fi
echo "Selected: $target"
echo "==========================================="
echo "The following operation needs root access"
echo "It will backup $grubfile first, and"
echo "make changes to the GRUB_DEFAULT if needed"
echo "==========================================="

# Set the understanding risk answer as "yes" automatically
ans="y"

case $ans in
    "Y" | "y")
        grep "^GRUB_DEFAULT=saved" $grubfile > /dev/null
        if [ $? -ne 0 ]; then
            echo "Backing up your grub file to ./grub-bak"
            cp "$grubfile" ./grub-bak
            echo "Changing GRUB_DEFAULT to 'saved' in $grubfile"
            sudo sed -i "s/GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" $grubfile
            sudo update-grub
        fi
        if [ $one_time = true ]; then
            echo "Setting up one-time task with grub-reboot..."
            cmd="sudo grub-reboot $target"
            eval $cmd
        else
            echo "Setting up default boot option with grub-set-default..."
            cmd="sudo grub-set-default $target"
            eval $cmd
        fi
        echo "Job done, please reboot now."
        ;;
    *)
        echo "User aborted."
        ;;
esac

