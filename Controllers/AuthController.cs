using Microsoft.AspNetCore.Mvc;
using ADSoftAPI.Services;

namespace ADSoftAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly JwtService _jwtService;
        private readonly IConfiguration _configuration;

        public AuthController(JwtService jwtService, IConfiguration configuration)
        {
            _jwtService = jwtService;
            _configuration = configuration;
        }

        [HttpPost("token")]
        public IActionResult GetToken([FromHeader(Name = "X-API-Key")] string apiKey)
        {
            // Validate API key
            var allowedApiKeys = _configuration.GetSection("ClientAuthentication:ApiKeys")
                .Get<Dictionary<string, string>>();

            // Find the client ID associated with this API key
            var clientId = allowedApiKeys?.FirstOrDefault(x => x.Value == apiKey).Key;
            
            if (string.IsNullOrEmpty(clientId))
            {
                return Unauthorized("Invalid API key");
            }

            // Generate JWT token
            var token = _jwtService.GenerateToken(clientId);

            return Ok(new { 
                token = token,
                expires_in = _configuration["Jwt:ExpiryInMinutes"],
                token_type = "Bearer"
            });
        }
    }
}
