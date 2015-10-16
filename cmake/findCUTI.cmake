cmake_minimum_required(VERSION 2.8)

set(CUTI_TOP_DIR ../../)

if(CUTI_USES_MSVC_UNIT_BACKEND)
	if(WIN32)
		add_definitions(-DCUTI_USES_MSVC_UNIT_BACKEND)
		add_definitions(-DCUTI_EXCLUDE_TEST_FROM_COVERAGE)
		set(MSVC_UNIT_TEST_DIR "C:/Program Files (x86)/Microsoft Visual Studio 12.0/VC/UnitTest/")#TODO make it discoverable
		include_directories(${MSVC_UNIT_TEST_DIR}/include)
		link_directories(${MSVC_UNIT_TEST_DIR}lib/)
		set(CUTI_UNIT_TEST_LIBRARIES_DEBUG Microsoft.VisualStudio.TestTools.CppUnitTestFramework.lib)
		set(CUTI_UNIT_TEST_LIBRARIES_RELEASE Microsoft.VisualStudio.TestTools.CppUnitTestFramework.lib)
	endif(WIN32)
else(CUTI_USES_MSVC_UNIT_BACKEND)
	add_definitions(-DCUTI_USES_CPPUNIT_BACKEND)
	add_definitions(-DCPPUNIT_DLL)
	include_directories(${CUTI_TOP_DIR}cppunit/include)
	#TODO make it generic
	get_filename_component(CUTI_UNIT_TEST_LIBRARIES_DEBUG ${CUTI_TOP_DIR}cppunit/lib/cppunitd_dll.lib ABSOLUTE)
	get_filename_component(CUTI_UNIT_TEST_LIBRARIES_RELEASE ${CUTI_TOP_DIR}cppunit/lib/cppunit_dll.lib ABSOLUTE)
endif(CUTI_USES_MSVC_UNIT_BACKEND)

include_directories(${CUTI_TOP_DIR}include)
get_filename_component(CUTI_INCLUDE ${CUTI_TOP_DIR}include/Cuti.h ABSOLUTE)