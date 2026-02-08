Encrypting disk Image partition using LUKS 2

# Modifying Image

#1 Once the image is genrated run following script to create an encrypted partition.
#2 Make sure you have already created partition with LABEL "datafs_enc" in your WKS script.
  sudo ./encrypt_and_copy_postbuild.sh ./../../../MPU_Flash_Tools/rvc-image-dev.wic datafs_enc ./luks_key.bin aes-cbc-essiv:sha256
#3 Now flash the image to your RVC board using UUU utility with image that you encrypted in above step
#4 Run the following command to decrypt the encrypted key placed in /etc/keys. The key encryption password which is  "beko@r&d_bsp321!" will be stored in HSM
  openssl enc -d -aes-256-cbc -salt -in /etc/keys/luks_key.bin.enc -out /tmp/luks_key.bin -k "beko@r&d_bsp321!"
#5 Keep in mind you have to store  key encryption password  "beko@r&d_bsp321!" in HSM.
#6 Run the /usr/local/bin/mount_encrypted_partition.sh to load dm-crypt module and mount partition at /media/dafafs_enc
  /usr/local/bin/mount_encrypted_partition.sh /tmp/luks_key.bin /dev/mmcblk2p7 datafs_enc_mapped /media/datafs_enc
#7 Run following command to test read and write speed for encrypted storage.
  time dd if=/dev/zero of=/media/datafs_enc/testfile bs=10M count=10 oflag=direct
  time dd if=/media/datafs_enc/testfile of=/dev/null bs=10M count=10 iflag=direct
  
