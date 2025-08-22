namespace ADSoftAPI.Models
{
    public class ConfigurationRequest
    {
        public string Value { get; set; } = string.Empty;
    }

    public class EncryptionKeysResponse
    {
        public string Key { get; set; } = string.Empty;
        public string IV { get; set; } = string.Empty;
        public string AppsettingsFormat { get; set; } = string.Empty;
    }

    public class EncryptionResponse
    {
        public string OriginalValue { get; set; } = string.Empty;
        public string EncryptedValue { get; set; } = string.Empty;
        public string AppsettingsFormat { get; set; } = string.Empty;
    }
}
