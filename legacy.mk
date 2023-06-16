# Legacy tests

# handle legacy config test
CONFIG_VERSION:=latest
TEST_SITE_STRING=${TEST_SITE}
ifeq ($(CONFIG_VERSION),202305)
	TEST_SITE_STRING=https://${TEST_SITE}
endif