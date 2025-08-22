using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using ADSoftAPI.Services;
using ADSoftAPI.Models;

namespace ADSoftAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ADUserController : ControllerBase
    {
        private readonly ActiveDirectoryService _adService;
        private readonly IConfiguration _configuration;

        public ADUserController(ActiveDirectoryService adService, IConfiguration configuration)
        {
            _adService = adService;
            _configuration = configuration;
        }

        [HttpGet("{username}")]
        public async Task<IActionResult> GetUserDetails(string username, [FromHeader(Name = "X-API-Key")] string apiKey)
        {
            // Validate API key
            var allowedApiKeys = _configuration.GetSection("ClientAuthentication:ApiKeys")
                .Get<Dictionary<string, string>>();

            if (!allowedApiKeys.ContainsValue(apiKey))
            {
                return Unauthorized("Invalid API key");
            }

            var userDetails = await _adService.GetUserDetailsAsync(username);
            if (userDetails == null)
            {
                return NotFound($"User {username} not found");
            }

            return Ok(userDetails);
        }

        [HttpGet("ou/{ouName}")]
        public async Task<IActionResult> GetUsersByOU(string ouName, [FromHeader(Name = "X-API-Key")] string apiKey)
        {
            // Validate API key
            var allowedApiKeys = _configuration.GetSection("ClientAuthentication:ApiKeys")
                .Get<Dictionary<string, string>>();

            if (allowedApiKeys == null || !allowedApiKeys.ContainsValue(apiKey))
            {
                return Unauthorized("Invalid API key");
            }

            var users = await _adService.GetUsersByOUAsync(ouName);
            if (users == null || users.Count == 0)
            {
                return NotFound($"No users found in OU: {ouName}");
            }

            return Ok(users);
        }
    }
}
