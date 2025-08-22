using Microsoft.AspNetCore.Mvc;
using ADSoftAPI.Services;
using ADSoftAPI.Models;
using System.Text.Json;

namespace ADSoftAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ConfigurationController : ControllerBase
    {
        private readonly ConfigurationService _configService;
        private readonly ILogger<ConfigurationController> _logger;

        public ConfigurationController(
            ConfigurationService configService,
            ILogger<ConfigurationController> logger)
        {
            _configService = configService;
            _logger = logger;
        }

        [HttpGet("generate-keys")]
        public ActionResult<EncryptionKeysResponse> GenerateNewKeys()
        {
            try
            {
                var (key, iv) = _configService.GenerateNewEncryptionKeys();
                
                // Create the appsettings.json format
                var config = new
                {
                    ActiveDirectory = new
                    {
                        Encryption = new
                        {
                            Key = key,
                            IV = iv
                        }
                    }
                };

                var response = new EncryptionKeysResponse
                {
                    Key = key,
                    IV = iv,
                    AppsettingsFormat = JsonSerializer.Serialize(config, new JsonSerializerOptions 
                    { 
                        WriteIndented = true 
                    })
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate new encryption keys");
                return StatusCode(500, "Failed to generate encryption keys");
            }
        }

        [HttpPost("encrypt")]
        public ActionResult<EncryptionResponse> EncryptValue([FromBody] ConfigurationRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Value))
                {
                    return BadRequest("Value to encrypt cannot be empty");
                }

                var encryptedValue = _configService.EncryptValue(request.Value);
                
                var response = new EncryptionResponse
                {
                    OriginalValue = request.Value,
                    EncryptedValue = encryptedValue,
                    AppsettingsFormat = $"\"EncryptedValue\": \"{encryptedValue}\""
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to encrypt value");
                return StatusCode(500, "Failed to encrypt value");
            }
        }

        [HttpPost("decrypt")]
        public ActionResult<string> DecryptValue([FromBody] ConfigurationRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Value))
                {
                    return BadRequest("Value to decrypt cannot be empty");
                }

                var decryptedValue = _configService.DecryptValue(request.Value);
                return Ok(new { DecryptedValue = decryptedValue });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to decrypt value");
                return StatusCode(500, "Failed to decrypt value");
            }
        }
    }
}
