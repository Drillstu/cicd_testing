pipeline {
    agent any
    stages {
        stage('1. Baixar do GitHub') {
            steps {
                // PADRÃO DE PRODUÇÃO: Pega a URL e a Branch dinamicamente de onde o script foi baixado
                checkout scm
            }
        }
        stage('2. Copiar para o Servidor') {
            steps {
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\* 2>nul'
                bat 'xcopy /E /Y . D:\\IRIS_Server\\projectGit\\'
            }
        }
        stage('3. Backup e Deploy no IRIS') {
            options {
                timeout(time: 1, unit: 'MINUTES') 
            }
            steps {
                // Esse script agora cria o backup_anterior.xml ANTES de aplicar o código novo
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\importar.script || exit 0'
            }
        }
        stage('4. Executar Testes Unitários') {
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\testes.script'
            }
        }
    }
    
    post {
        failure {
            echo '🚨 Os testes falharam! Voltando o servidor para o estado anterior usando o backup...'
            // O rollback agora reimporta o XML original salvo no Estágio 3
            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\rollback.script || exit 0'
        }
        success {
            echo '✅ Pipeline concluído com sucesso. Nenhuma falha detectada!'
        }
    }
}
