//
//  BitwardenEncryption.m
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

#import "BWEncryption.h"
#import "os/log.h"

#define KEY_LENGTH      2048
#define PUB_EXP         65537
#define IV_LENGTH       16
#define BLOCK_SIZE      16
#define SHARED_KEY_SIZE  64

@interface BWEncryption ()

// Key pair is used for encryption(public key - server) and decryption(private key - client) of the shared key
@property (nonatomic) RSA *keypair;

// Shared key is received from Bitwarden
// First half (32 bytes) is used for encryption/decryption of messages
// Second half (32 bytes) for hmac
@property (nonatomic) NSData *sharedKeyData;

@property (nonatomic) NSData *encryptionKeyData;
@property (nonatomic) AES_KEY encryptionKey;
@property (nonatomic) AES_KEY decryptionKey;
@property (nonatomic) NSData *macKeyData;

@end

@implementation BWEncryption

-(void)dealloc {
    RSA_free(self.keypair);
}

- (nullable NSString *)generateKeys {
    BIGNUM *bignum = BN_new();
    BN_set_word(bignum, PUB_EXP);

    self.keypair = RSA_new();
    int result = RSA_generate_key_ex(self.keypair, KEY_LENGTH, bignum, NULL);
    if (!result) {
        return NULL;
    }

    // Return the public key in the desired format
    BIO *output = BIO_new(BIO_s_mem());
    result = i2d_RSA_PUBKEY_bio(output,self.keypair);
    if (!result) {
        return NULL;
    }
    size_t outputLength = BIO_pending(output);
    char   *outputKey = calloc(outputLength + 1, sizeof(unsigned char));
    BIO_read(output, outputKey, (int)outputLength);

    NSData *outputData = [NSData dataWithBytes:outputKey length:outputLength];

    free(outputKey);
    return [outputData base64EncodedStringWithOptions:0];
}

- (BOOL)setSharedKey:(NSData *)sharedKey {
    if ([sharedKey length] != SHARED_KEY_SIZE) {
        return false;
    }

    self.sharedKeyData = sharedKey;
    // First 32 bytes are encryption/decryption key
    self.encryptionKeyData = [self.sharedKeyData subdataWithRange:NSMakeRange(0, 32)];
    AES_set_encrypt_key(self.encryptionKeyData.bytes, (int)self.encryptionKeyData.length * 8, &_encryptionKey);
    AES_set_decrypt_key(self.encryptionKeyData.bytes, (int)self.encryptionKeyData.length * 8, &_decryptionKey);

    // Last 32 bytes are mac key
    self.macKeyData = [self.sharedKeyData subdataWithRange:NSMakeRange(32, 32)];
    return true;
}

- (nullable NSString *)decryptSharedKey:(NSString *)encryptedSharedKey {
    // Make sure key pair is generated
    if (self.keypair == NULL) { return nil; }
    [self cleanKeyData];

    NSData *encryptedSharedKeyData = [[NSData alloc] initWithBase64EncodedString:encryptedSharedKey options:0];
    unsigned char *encryptedSharedKeyDataPointer = (unsigned char *)[encryptedSharedKeyData bytes];

    // Decrypt the shared key
    unsigned char decryptedDataArray[2560] = { 0 };
    int decryptedLength = RSA_private_decrypt(RSA_size(self.keypair),
                                              encryptedSharedKeyDataPointer,
                                              decryptedDataArray,
                                              self.keypair,
                                              RSA_PKCS1_OAEP_PADDING);
    if(decryptedLength == -1) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,"OpenSSLWrapper: Decryption of the shared key failed %s",
                         ERR_error_string(ERR_get_error(), NULL));
        return nil;
    }

    NSData *sharedKeyData = [NSData dataWithBytes:decryptedDataArray length:decryptedLength];

    // Hold for further communication
    [self setSharedKey:sharedKeyData];

    // Return to store for future sessions
    return [sharedKeyData base64EncodedStringWithOptions:0];
}

- (nullable BWEncryptionOutput *)encryptData:(NSData *)data {
    if (self.macKeyData == nil) { return nil; }

    NSData *ivData = [self generateIv];
    if (ivData == nil) { return nil; }

    unsigned char *dataArray = (unsigned char *)data.bytes;
    size_t dataArrayLength = data.length;

    // AES has a fixed block size of 16-bytes regardless key size
    size_t encryptedDataLength = ceil((float)dataArrayLength / (float)BLOCK_SIZE) * BLOCK_SIZE;
    unsigned char *encryptionOutput = calloc(encryptedDataLength, sizeof(unsigned char));

    unsigned char *ivBytes = (unsigned char *)ivData.bytes;
    unsigned char ivCopy[IV_LENGTH];
    memcpy(&ivCopy, ivBytes, IV_LENGTH);

    // Encrypt
    AES_cbc_encrypt(dataArray, encryptionOutput, dataArrayLength, &_encryptionKey, (unsigned char *)ivCopy, AES_ENCRYPT);

    NSData *encryptedData = [NSData dataWithBytes:encryptionOutput length: encryptedDataLength];
    free(encryptionOutput);

    // Compute HMAC
    NSData *hmacData = [self computeHmac:encryptedData iv:ivData];

    // Wrap into EncryptionOutput structure
    BWEncryptionOutput *encryptionOutputObject = [[BWEncryptionOutput alloc] init];
    encryptionOutputObject.iv = ivData;
    encryptionOutputObject.data = encryptedData;
    encryptionOutputObject.hmac = hmacData;
    return encryptionOutputObject;
}

- (nullable NSData *)generateIv {
    unsigned char iv[IV_LENGTH];
    if(SecRandomCopyBytes(kSecRandomDefault, IV_LENGTH, &iv) != errSecSuccess) {
        return nil;
    }
    return [NSData dataWithBytes:iv length:IV_LENGTH];
}

- (NSData *)computeHmac:(NSData *)data iv:(NSData *)ivData {
    NSMutableData *macData = [NSMutableData data];
    [macData appendData:ivData];
    [macData appendData:data];

    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, self.macKeyData.bytes, self.macKeyData.length, macData.bytes, macData.length, cHMAC);
    NSData *hash = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];

    return hash;
}

- (NSData *)decryptData:(NSData *)data andIv:(NSData *)ivData {
    unsigned char *decryptionOutput;

    // AES has a fixed block size of 16-bytes regardless key size
    size_t decryptionOutputLength = (data.length/BLOCK_SIZE + 1) * BLOCK_SIZE;
    decryptionOutput = calloc(decryptionOutputLength, sizeof(unsigned char));

    unsigned char *ivBytes = (unsigned char *)ivData.bytes;
    unsigned char ivCopy[ivData.length];
    memcpy(&ivCopy, ivBytes, ivData.length);

    // Decrypt
    AES_cbc_encrypt(data.bytes, decryptionOutput, data.length, &_decryptionKey, (unsigned char *)ivCopy, AES_DECRYPT);

    // Padding removal
    for(;!isgraph(*(decryptionOutput+(decryptionOutputLength - 1)));decryptionOutputLength--);

    NSData *decryptedData = [NSData dataWithBytes:decryptionOutput length: decryptionOutputLength];
    free(decryptionOutput);

    return decryptedData;
}

- (void)cleanKeys {
    RSA_free(self.keypair);
    self.keypair = nil;

    [self cleanKeyData];
}

- (void)cleanKeyData {
    self.sharedKeyData = nil;
    self.encryptionKeyData = nil;
    self.macKeyData = nil;
}

@end
