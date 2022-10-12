//
//  OpenSSLWrapper.m
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "OpenSSLWrapper.h"
#import "os/log.h"

#define KEY_LENGTH  2048
#define PUB_EXP     65537

@implementation OpenSSLWrapper

// Key pair is used for encryption(public key - server) and decryption(private key - client) of the shared key
RSA *keypair;

// Shared key is received from Bitwarden
// First half (32 bytes) is used for encryption/decryption of messages
// Second half (32 bytes) for hmac
NSData *sharedKeyData;
NSData *encryptionKeyData;
NSData *macKeyData;

- (nullable NSString *)generateKeys {
    // Generate key pair
    keypair = RSA_generate_key(KEY_LENGTH, PUB_EXP, NULL, NULL);

    // Return the public key in the desired format
    size_t outputLength;
    char   *outputKey;
    BIO *output = BIO_new(BIO_s_mem());
    int result = i2d_RSA_PUBKEY_bio(output,keypair);
    if (!result) {
        return NULL;
    }
    outputLength = BIO_pending(output);
    outputKey = calloc(outputLength + 1, sizeof(unsigned char));
    BIO_read(output, outputKey, (int)outputLength);

    NSData *outputData = [NSData dataWithBytes:outputKey length:outputLength];

    free(outputKey);
    return [outputData base64EncodedStringWithOptions:0];
}

- (void)cleanKeyData {
    sharedKeyData = nil;
    encryptionKeyData = nil;
    macKeyData = nil;
}

- (BOOL)decryptSharedKey:(NSString *)encryptedSharedKey {
    // Make sure key pair is generated
    if (keypair == NULL) { return false; }
    [self cleanKeyData];

    NSData *encryptedSharedKeyData = [[NSData alloc] initWithBase64EncodedString:encryptedSharedKey options:0];
    unsigned char *encryptedSharedKeyDataPointer = (unsigned char *)[encryptedSharedKeyData bytes];

    // Decrypt the shared key
    unsigned char decryptedDataArray[2560] = { 0 };
    int decryptedLength = RSA_private_decrypt(RSA_size(keypair),
                                              encryptedSharedKeyDataPointer,
                                              decryptedDataArray,
                                              keypair,
                                              RSA_PKCS1_OAEP_PADDING);
    if(decryptedLength == -1) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,"OpenSSLWrapper: Decryption of the shared key failed %s",
                         ERR_error_string(ERR_get_error(), NULL));
        return false;
    }

    // Hold for further communication
    sharedKeyData = [NSData dataWithBytes:decryptedDataArray length:decryptedLength];
    if (decryptedLength != 64) {
        return false;
    }

    encryptionKeyData = [sharedKeyData subdataWithRange:NSMakeRange(0, 32)];
    macKeyData = [sharedKeyData subdataWithRange:NSMakeRange(32, 32)];

    return true;
}

- (EncryptedMessage *)encryptData:(NSData *)data {

    //TODO: Generate iv - random 16 bytes
    NSData *ivData = [macKeyData subdataWithRange:NSMakeRange(0, 16)];

    unsigned char enc_out[500];
    int i;
    for(i=0;i < 500;i++) {
        enc_out[i] = 0;
    }

    unsigned char dataArray[32];
    for(i=0;i < 32;i++) {
        dataArray[i] = 0;
    }
    memcpy(&dataArray, data.bytes, data.length);

    unsigned char *ivBytes = (unsigned char *)ivData.bytes;
    unsigned char ivCopy[16];
    memcpy(&ivCopy, ivBytes, 16);

    //TODO: Set global encryption and decryption key
    // Encrypt
    AES_KEY enc_key;
    AES_set_encrypt_key(encryptionKeyData.bytes, (int)encryptionKeyData.length * 8, &enc_key);
    AES_cbc_encrypt(dataArray, enc_out, 32, &enc_key, (unsigned char *)ivCopy, AES_ENCRYPT);

    for(i=0;*(enc_out+i)!=0x00;i++);
    NSData *encryptedData = [NSData dataWithBytes:enc_out length: i];

    // Compute HMAC
    NSMutableData *macData = [NSMutableData data];
    [macData appendData:ivData];
    [macData appendData:encryptedData];

    unsigned char *hmac = NULL;
    unsigned int hmacLength = -1;

    hmac = HMAC(EVP_sha256(),macKeyData.bytes, (int)macKeyData.length * 8, macData.bytes, (int)macData.length, hmac, &hmacLength);
    NSData *hmacData = [[NSData alloc] initWithBytes:hmac length:hmacLength];

    // Wrap into EncryptedMessage structure
    EncryptedMessage *encryptedMessage = [[EncryptedMessage alloc] init];
    encryptedMessage.iv = ivData;
    encryptedMessage.data = encryptedData;
    encryptedMessage.hmac = hmacData;
    return encryptedMessage;
}

- (NSData *)decryptData:(NSData *)data andIv:(NSData *)ivData {
    unsigned char dec_out[2000];
    int i;
    for(i=0;i < 2000;i++) {
        dec_out[i] = 0;
    }

    unsigned char *ivBytes = (unsigned char *)ivData.bytes;
    unsigned char ivCopy[ivData.length];
    memcpy(&ivCopy, ivBytes, ivData.length);

    AES_KEY dec_key;
    AES_set_decrypt_key(encryptionKeyData.bytes, (int)encryptionKeyData.length * 8, &dec_key);
    AES_cbc_encrypt(data.bytes, dec_out, data.length, &dec_key, (unsigned char *)ivCopy, AES_DECRYPT);

    for(i=0;*(dec_out+i)!=0x00;i++);

    //TODO: Padding removal
    for(;*(dec_out+(i-1))==0x03;i--);

    NSData *decryptedData = [NSData dataWithBytes:dec_out length: i];
    return decryptedData;
}

@end

@implementation EncryptedMessage

@end
