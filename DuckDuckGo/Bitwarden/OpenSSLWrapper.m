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
#define WRITE_TO_FILE

@implementation OpenSSLWrapper

RSA *keypair;

// Returns public key base64 encoded
- (NSString *)generateKeys {
    size_t pri_len;            // Length of private key
    size_t pub_len;            // Length of public key
    size_t output_len;            // Length of public key
    char   *pri_key;           // Private key
    char   *pub_key;           // Public key
    char   *output_key;           // Public key

    // Generate key pair
    keypair = RSA_generate_key(KEY_LENGTH, PUB_EXP, NULL, NULL);

    //TODO REMOVE
#ifdef DEBUG

    // To get the C-string PEM form:
    BIO *pri = BIO_new(BIO_s_mem());
    BIO *pub = BIO_new(BIO_s_mem());

    PEM_write_bio_RSAPrivateKey(pri, keypair, NULL, NULL, 0, NULL, NULL);
    PEM_write_bio_RSAPublicKey(pub, keypair);

    pri_len = BIO_pending(pri);
    pub_len = BIO_pending(pub);

    pri_key = malloc(pri_len + 1);
    pub_key = malloc(pub_len + 1);

    BIO_read(pri, pri_key, pri_len);
    BIO_read(pub, pub_key, pub_len);

    pri_key[pri_len] = '\0';
    pub_key[pub_len] = '\0';

    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG, "\n%s\n%s\n", pri_key, pub_key);

    free(pri_key);
    free(pub_key);
#endif

    //TODO check return values

    BIO *output = BIO_new(BIO_s_mem());
    i2d_RSA_PUBKEY_bio(output,keypair);
    output_len = BIO_pending(output);
    output_key = malloc(output_len + 1);
    BIO_read(output, output_key, output_len);

    NSData *outputData = [NSData dataWithBytes:output_key length:output_len];

    free(output_key);
    return [outputData base64EncodedStringWithOptions:0];
}


@end
