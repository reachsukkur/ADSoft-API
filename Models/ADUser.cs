using System;

namespace ADSoftAPI.Models
{
    public class ADUser
    {
        public string SamAccountName { get; set; }
        public string EmailAddress { get; set; }
        public string DisplayName { get; set; }
        public string DisplayNameArabic { get; set; }
        public string ProfilePicture { get; set; }
        public Dictionary<string, string> AdditionalAttributes { get; set; } = new Dictionary<string, string>();
    }
}
