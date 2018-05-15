using Xunit;

namespace UnitTests
{
    public class SmokeTest
    {
        [Fact]
        public void CanAssertTrue()
        {
            Assert.True(true, "Our first test!");
        }
    }
}
