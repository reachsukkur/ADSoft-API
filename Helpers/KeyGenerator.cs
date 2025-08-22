using System.Security.Cryptography;

namespace ADSoftAPI.Helpers
{
    public static class KeyGenerator
    {
        // public static void Main()
        // {
        //     using (var aes = Aes.Create())
        //     {
        //         aes.GenerateKey();
        //         aes.GenerateIV();

        //         Console.WriteLine($"Generated Key (Base64): {Convert.ToBase64String(aes.Key)}");
        //         Console.WriteLine($"Generated IV (Base64):  {Convert.ToBase64String(aes.IV)}");

        //         // Test encryption
        //         var helper = new EncryptionHelper(new ConfigurationBuilder()
        //             .AddInMemoryCollection(new Dictionary<string, string>
        //             {
        //                 ["ActiveDirectory:Encryption:Key"] = Convert.ToBase64String(aes.Key),
        //                 ["ActiveDirectory:Encryption:IV"] = Convert.ToBase64String(aes.IV)
        //             })
        //             .Build());

        //         var testValue = "TestValue123";
        //         var encrypted = helper.EncryptString(testValue);
        //         var decrypted = helper.DecryptString(encrypted);

        //         Console.WriteLine($"\nTest encryption/decryption:");
        //         Console.WriteLine($"Original:  {testValue}");
        //         Console.WriteLine($"Encrypted: {encrypted}");
        //         Console.WriteLine($"Decrypted: {decrypted}");
        //     }
        // }
    }
}
