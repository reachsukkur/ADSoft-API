using System.Security.Cryptography;
using ADSoftAPI.Helpers;

namespace ADSoftAPI.Services
{
    public class ConfigurationService
    {
        private readonly EncryptionHelper _encryptionHelper;
        private readonly ILogger<ConfigurationService> _logger;

        public ConfigurationService(EncryptionHelper encryptionHelper, ILogger<ConfigurationService> logger)
        {
            _encryptionHelper = encryptionHelper;
            _logger = logger;
        }

        public (string Key, string IV) GenerateNewEncryptionKeys()
        {
            try
            {
                using (var aes = Aes.Create())
                {
                    aes.GenerateKey();
                    aes.GenerateIV();
                    return (
                        Convert.ToBase64String(aes.Key),
                        Convert.ToBase64String(aes.IV)
                    );
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate new encryption keys");
                throw;
            }
        }

        public string EncryptValue(string plaintext)
        {
            try
            {
                _logger.LogInformation("Encrypting configuration value");
                return _encryptionHelper.EncryptString(plaintext);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to encrypt configuration value");
                throw;
            }
        }

        public string DecryptValue(string encryptedValue)
        {
            try
            {
                _logger.LogInformation("Decrypting configuration value");
                return _encryptionHelper.DecryptString(encryptedValue);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to decrypt configuration value");
                throw;
            }
        }
    }
}
