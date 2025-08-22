using System.DirectoryServices.AccountManagement;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using ADSoftAPI.Models;
using ADSoftAPI.Helpers;

namespace ADSoftAPI.Services
{
    public class ActiveDirectoryService
    {
        private readonly IConfiguration _configuration;
        private readonly string _domain;
        private readonly string _username;
        private readonly string _password;
        private readonly EncryptionHelper _encryptionHelper;
        private readonly ILogger<ActiveDirectoryService> _logger;

        public ActiveDirectoryService(
            IConfiguration configuration, 
            EncryptionHelper encryptionHelper,
            ILogger<ActiveDirectoryService> logger)
        {
            _configuration = configuration;
            _encryptionHelper = encryptionHelper;
            _logger = logger;
            
            _domain = _configuration["ActiveDirectory:Domain"] ?? 
                throw new InvalidOperationException("ActiveDirectory:Domain configuration is missing");
            
            _logger.LogInformation("Initializing Active Directory service for domain: {Domain}", _domain);
            
            try
            {
                // Decrypt credentials
                _username = _encryptionHelper.DecryptString(_configuration["ActiveDirectory:EncryptedUsername"]);
                _password = _encryptionHelper.DecryptString(_configuration["ActiveDirectory:EncryptedPassword"]);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to decrypt Active Directory credentials");
                throw;
            }
        }

        public async Task<ADUser> GetUserDetailsAsync(string username)
        {
            _logger.LogInformation("Searching for AD user: {Username}", username);
            
            try
            {
                using (var context = new PrincipalContext(ContextType.Domain, _domain, _username, _password))
                {
                    var user = UserPrincipal.FindByIdentity(context, IdentityType.SamAccountName, username);
                    if (user == null)
                    {
                        _logger.LogWarning("User not found: {Username}", username);
                        return null;
                    }

                    _logger.LogInformation("User found: {Username}", username);

                    var directoryEntry = user.GetUnderlyingObject() as System.DirectoryServices.DirectoryEntry;
                    var adUser = new ADUser
                    {
                        SamAccountName = user.SamAccountName,
                        EmailAddress = user.EmailAddress,
                        DisplayName = user.DisplayName,
                    };

                    // Try to get Arabic name if available
                    try
                    {
                        if (directoryEntry?.Properties["displayNameAr"]?.Value != null)
                        {
                            adUser.DisplayNameArabic = directoryEntry.Properties["displayNameAr"].Value.ToString();
                            _logger.LogDebug("Found Arabic name for user: {Username}", username);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to read Arabic name for user: {Username}", username);
                    }

                    // Try to get profile picture if available
                    try
                    {
                        var thumbnailPhoto = directoryEntry?.Properties["thumbnailPhoto"]?.Value as byte[];
                        if (thumbnailPhoto != null)
                        {
                            adUser.ProfilePicture = Convert.ToBase64String(thumbnailPhoto);
                            _logger.LogDebug("Found profile picture for user: {Username}", username);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to read profile picture for user: {Username}", username);
                    }

                    // Get all properties for discovery
                    try
                    {
                        if (directoryEntry?.Properties?.PropertyNames != null)
                        {
                            foreach (string propertyName in directoryEntry.Properties.PropertyNames)
                            {
                                try
                                {
                                    var value = directoryEntry.Properties[propertyName]?.Value?.ToString();
                                    if (!string.IsNullOrEmpty(value))
                                    {
                                        adUser.AdditionalAttributes[propertyName] = value;
                                    }
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogWarning(ex, "Failed to read property {PropertyName} for user: {Username}", propertyName, username);
                                }
                            }
                            _logger.LogInformation("Retrieved {PropertyCount} additional properties for user: {Username}",
                                adUser.AdditionalAttributes.Count, username);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to enumerate AD properties for user: {Username}", username);
                    }

                    return adUser;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving AD user details for: {Username}", username);
                throw;
            }
        }

        public async Task<List<ADUser>> GetUsersByOUAsync(string ouName)
        {
            _logger.LogInformation("Searching for users in OU: {OUName}", ouName);
            
            try
            {
                using (var context = new PrincipalContext(ContextType.Domain, _domain, _username, _password))
                {
                    var users = new List<ADUser>();
                    
                    // Search for users in the specified OU
                    var userPrincipal = new UserPrincipal(context);
                    var searcher = new PrincipalSearcher(userPrincipal);
                    
                    foreach (UserPrincipal user in searcher.FindAll())
                    {
                        if (user.DistinguishedName.Contains($"OU={ouName}"))
                        {
                            _logger.LogDebug("Processing user: {Username}", user.SamAccountName);
                            
                            var directoryEntry = user.GetUnderlyingObject() as System.DirectoryServices.DirectoryEntry;
                            var adUser = new ADUser
                            {
                                SamAccountName = user.SamAccountName,
                                EmailAddress = user.EmailAddress,
                                DisplayName = user.DisplayName,
                            };

                            // Try to get Arabic name if available
                            try
                            {
                                if (directoryEntry?.Properties["displayNameAr"]?.Value != null)
                                {
                                    adUser.DisplayNameArabic = directoryEntry.Properties["displayNameAr"].Value.ToString();
                                    _logger.LogDebug("Found Arabic name for user: {Username}", user.SamAccountName);
                                }
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning(ex, "Failed to read Arabic name for user: {Username}", user.SamAccountName);
                            }

                            // Try to get profile picture if available
                            try
                            {
                                var thumbnailPhoto = directoryEntry?.Properties["thumbnailPhoto"]?.Value as byte[];
                                if (thumbnailPhoto != null)
                                {
                                    adUser.ProfilePicture = Convert.ToBase64String(thumbnailPhoto);
                                    _logger.LogDebug("Found profile picture for user: {Username}", user.SamAccountName);
                                }
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning(ex, "Failed to read profile picture for user: {Username}", user.SamAccountName);
                            }

                            // Note: Not including AdditionalAttributes as requested
                            users.Add(adUser);
                        }
                    }
                    
                    _logger.LogInformation("Found {UserCount} users in OU: {OUName}", users.Count, ouName);
                    return users;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving users from OU: {OUName}", ouName);
                throw;
            }
        }

        // Encryption/Decryption moved to EncryptionHelper
    }
}
