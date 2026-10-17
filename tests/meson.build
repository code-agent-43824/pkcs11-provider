ec_point_test = executable(
  'tecpoint',
  ['tecpoint.c', '../src/obj/ec_point.c'],
  build_by_default: false,
  include_directories: [configinc, include_directories('../src')],
  dependencies: [libcrypto],
)
uri_parse_test = executable(
  'turi_parse',
  ['turi_parse.c'],
  objects: pkcs11_provider.extract_all_objects(),
  include_directories: [configinc, include_directories('../src')],
  dependencies: [libcrypto, dl_dep, pthread_dep],
)
pin_flags_test = executable(
  'tpin_flags',
  ['tpin_flags.c'],
  objects: pkcs11_provider.extract_all_objects(),
  include_directories: [configinc, include_directories('../src')],
  dependencies: [libcrypto, dl_dep, pthread_dep],
)

test('ec-point-decode', ec_point_test, suite: 'unittests')
test('uri-parse', uri_parse_test, suite: 'unittests')
test('pin-flags', pin_flags_test, suite: 'unittests')

if host_machine.system() == 'windows'
  pkcs11_abi_test = executable(
    'tpkcs11_abi',
    ['tpkcs11_abi.c'],
    include_directories: include_directories('../src'),
  )
  test('pkcs11-windows-abi', pkcs11_abi_test, suite: 'unittests')
endif

if cc.get_id() == 'msvc'
  msvc_load_test = executable('tmsvc_load', 'tmsvc_load.c',
                              dependencies: [libcrypto])
  test('msvc-provider-load', msvc_load_test,
       env: ['OPENSSL_MODULES=' + (meson.project_build_root() / 'src')],
       suite: 'msvc')
endif
