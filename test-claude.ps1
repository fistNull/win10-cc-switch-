$env:ANTHROPIC_API_KEY='sk-z4wBLi4jDupjg3FatUkNPetZ6kepFFE66iNdsHMprT3pw1qw'
$env:ANTHROPIC_BASE_URL='https://a-ocnfniawgw.cn-shanghai.fcapp.run'
& node "D:\Program Files\nodejs\node_global\node_modules\@anthropic-ai\claude-code\cli.js" --help 2>&1 | Select-Object -First 5
