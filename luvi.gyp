{
  'targets': [
    {
      'target_name': 'luvi',
      'type': 'executable',
      'dependencies': [
        'luajit.gyp:libluajit',
        'luv/libuv/uv.gyp:libuv',
      ],
      'sources': [
        'src/lua/init.lua',
        'src/lua/zipreader.lua',
        'src/main.c',
      ],
      'msvs-settings': {
        'VCLinkerTool': {
          'SubSystem': 1, # /subsystem:console
        },
      },
      'rules': [
        {
          'rule_name': 'bytecompile_lua',
          'extension': 'lua',
          'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/generated/<(RULE_INPUT_ROOT)_jit.c'

          ],
          'action': [ 'luajit', '-bg', '<(RULE_INPUT_PATH)', '<@(_outputs)'],
          'process_outputs_as_sources': 1,
          'message': 'luajit <(RULE_INPUT_PATH)'
        },
      ],
      'conditions': [
        ['OS == "win"',
          {
            'libraries': [
              '-lgdi32.lib',
              '-luser32.lib'
            ],
          }
        ],
        ['OS == "mac" and target_arch == "x64"',
          {
            'xcode_settings': {
              'OTHER_LDFLAGS': ['-pagezero_size', '10000', '-image_base', '100000000']
            }
          }
        ],
      ],
    },
  ],
}
