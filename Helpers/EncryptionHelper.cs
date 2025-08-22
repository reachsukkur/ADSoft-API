using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;

namespace ADSoftAPI.Helpers
{
    public class EncryptionHelper
    {
        private readonly byte[] _key;
        private readonly byte[] _iv;
        private readonly ILogger<EncryptionHelper> _logger;

        public EncryptionHelper(IConfiguration configuration, ILogger<EncryptionHelper> logger)
        {
            _logger = logger;

            try
            {
                var key = configuration["ActiveDirectory:Encryption:Key"];
                var iv = configuration["ActiveDirectory:Encryption:IV"];

                if (string.IsNullOrEmpty(key) || string.IsNullOrEmpty(iv))
                    throw new InvalidOperationException("Encryption key or IV not configured");

                // Convert from Base64 to ensure proper key/IV format
                _key = Convert.FromBase64String(key);
                _iv = Convert.FromBase64String(iv);

                if (_key.Length != 32) // AES-256 requires 32 bytes
                    throw new InvalidOperationException("Encryption key must be 32 bytes (256 bits) when Base64 decoded");
                
                if (_iv.Length != 16) // AES requires 16 bytes IV
                    throw new InvalidOperationException("IV must be 16 bytes (128 bits) when Base64 decoded");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize encryption configuration");
                throw;
            }
        }

        public string EncryptString(string plainText)
        {
            if (string.IsNullOrEmpty(plainText)) return string.Empty;

            try
            {
                using (Aes aes = Aes.Create())
                {
                    aes.Key = _key;
                    aes.IV = _iv;
                    aes.Mode = CipherMode.CBC;
                    aes.Padding = PaddingMode.PKCS7;

                    ICryptoTransform encryptor = aes.CreateEncryptor();

                    using (MemoryStream msEncrypt = new MemoryStream())
                    {
                        using (CryptoStream csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                        {
                            byte[] plainBytes = Encoding.UTF8.GetBytes(plainText);
                            csEncrypt.Write(plainBytes, 0, plainBytes.Length);
                            csEncrypt.FlushFinalBlock();
                        }

                        return Convert.ToBase64String(msEncrypt.ToArray());
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to encrypt string");
                throw;
            }
        }

        public string DecryptString(string cipherText)
        {
            if (string.IsNullOrEmpty(cipherText)) return string.Empty;

            try
            {
                byte[] cipherBytes = Convert.FromBase64String(cipherText);

                using (Aes aes = Aes.Create())
                {
                    aes.Key = _key;
                    aes.IV = _iv;
                    aes.Mode = CipherMode.CBC;
                    aes.Padding = PaddingMode.PKCS7;

                    ICryptoTransform decryptor = aes.CreateDecryptor();

                    using (MemoryStream msDecrypt = new MemoryStream(cipherBytes))
                    using (CryptoStream csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                    {
                        byte[] plainBytes = new byte[cipherBytes.Length];
                        int decryptedByteCount = csDecrypt.Read(plainBytes, 0, plainBytes.Length);
                        return Encoding.UTF8.GetString(plainBytes, 0, decryptedByteCount);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to decrypt string: {CipherText}", cipherText);
                throw;
            }
        }

        // Helper method to generate new key and IV
        public static (string Key, string IV) GenerateNewKeyAndIV()
        {
            using (Aes aes = Aes.Create())
            {
                aes.GenerateKey();
                aes.GenerateIV();
                return (
                    Convert.ToBase64String(aes.Key),
                    Convert.ToBase64String(aes.IV)
                );
            }
        }
    }
}
