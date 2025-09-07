function [ber, numBits] = simula_qam1(EbNo, maxNumErrs, maxNumBits)
    
    %Funci� i Sortida
    %   La l�nia de dalt defineix una funci� que es diu simula_qam1 que simula
    %   una transmissi� de 4-QAM (o QPSK) a un canal AWGN
    %   Entrades:
    %       EbNo: relaci� d'energia per bit a densitat de soroll (en dB)
    %       maxNumErrs: nombre m�xim d'errors a acumular abans de parar la
    %       simulaci�
    %       maxNumBits: nombre m�xim de bits a simular.
    %   Sortides:
    %       ber: taxa d'error de bits (Bit Error Rate)
    %       numBits: nombre total de bits processats a la simulaci�
    
    
    %Verificaci� del nombre d'arguments:
    %   Aquesta instrucci� comprova que la funci� es truqui amb exactament 3
    %   arguments. Si no �s aix�, es llen�a un error.
    narginchk(3,3) 
    
    
    %�s de funcions extr�nseques:
    %   Aix� indica a MATLAB Coder que la funci� isBERToolSimulationStopped no
    %   es compilar� (es tractar� com una funci� externa).
    %   En simulacions amb BERTool es permet que l'usuari interrompi la
    %   simulaci�, i aquesta funci� comprova aquesta condici�.
    coder.extrinsic('isBERToolSimulationStopped')
    
    %Inicialitzaci� de variables de control
    %   S'inicialitzen a zero les variables:
    %       totErr: acumulador del nombre total d'errors detectats
    %       numBits: acumulador del nombre total de bits simulats
    %   A simulacions Monte Carlo es necessiten comptadors per determinar quan
    %   s'han aconseguit els llindars preestablerts
    totErr  = 0; % Number of errors observed
    numBits = 0; % Number of bits processed
    
    
    %Mapeig de s�mbols a bits
    %   Es defineix l'assignaci� de cada s�mbol de la constel�laci� a una
    %   seq��ncia de bits
    %   Es fa servir codi Gray, de manera que els s�mbols ve�ns difereixin en
    %   un sol bit, minimitzant l'error en cas de desviament
    %   Cada fila correspon a un s�mbol al mateix ordre que en 'constel_symb'
    
    constelBits = ['00';   % 1+1i
                   '01';   % -1+1i
                   '11';   % -1-1i
                   '10'];  % 1-1i
    
    
    %Definici� de la constel�laci� 4-QAM (QPSK) normalitzada:
    %   Es defineixen els 4 s�mbols complexos que representen la constel�laci� de
    %   QPSK
    %   Es multiplica per 1/2 per normalitzar la pot�ncia mitjana a 1
    %   La normalitzaci� �s important perqu� la pot�ncia del senyal sigui
    %   consistent i es pugui relacionar correctament amb la pot�ncia del
    %   soroll (Pn). A QPSK, els s�mbols sense normalitzar tenen magnitud.
    %   2^(1/2) normalitzar-los assegura que E[|s|^2]=1
    constelSymb = (1/sqrt(2)) * [ 1+1i; -1+1i; -1-1i; 1-1i ];
    
    
    %N�mero de s�mbols
    %   Es calcula cantidadSimbolos, que �s el nombre de punts de la constel�laci�
    %   En aquest cas cantidadSimbolos=4
    cantidadSimbolos = length(constelSymb);
    
    
    %Bits per s�mbol:
    %   Es calcula el nombre de bits que es poden representar amb cada s�mbol,
    %   fent servir la f�rmula bitsSimbolo=log2(cantidadSimbolos)
    %   Per cantidadSimbolos=4, bitsSimbolo=2
    %   Aquest par�metre �s clau per determinar l'efici�ncia de la modulaci�
    %   (m�s bits per s�mbol implica major efici�ncia espectral, per� tamb� major
    %   susceptibilitat al soroll)
    bitsSimbolo = log2(cantidadSimbolos);
    
    %N�mero de bits per bloc
    %   Defineix quants bits se simularan a cada iteraci� del bucle (bloc de
    %   simulaci�)
    %   Aqu� se simulen 10000 s�mbols, i per aix� el nombre de bits en cada bloc
    %   ser� de 10000*k (on k = 2)
    nbitsBloc = 10000 * bitsSimbolo;
    
    
    %Pot�ncia del senyal
    %   Es calcula la pot�ncia mitjana del senyal transm�s Ps
    %   S'utilitza la mitja del quadrat del valor absolut de cada s�mbol
    %   La pot�ncia del senyal �s fonamental per determinar el nivell de soroll
    %   necessari en funci� de la relaci� Eb/N0
    Ps = mean( abs(constelSymb) .^ 2);
    
    %Conversi� de dB a lineal
    %   Converteix el valor de Eb/N0 de decibels (dB) al seu valor lineal
    %   mitjan�ant la f�rmula 10^(EbNo/10)
    pRuidoEbNo = 10 ^ (EbNo / 10);
    
    %C�lcul de la pot�ncia del soroll
    %   Es calcula Pn, la pot�ncia del soroll, fent servir la relaci�:
    %   Pn=(Ps)/(k*(Eb/E0))
    %   Donat que l'energia per bit Eb es pot obtenir com (considerant el Ts=1)
    %   Eb=Ps/k
    %   i sabent que Eb/N0 no �s la ra� de senyal a soroll, es pot deduir que:
    %   N0=Eb/(Eb/N0)
    %   En aquesta simulaci�, es fa servir Pn com una aproximaci� del soroll
    %   que s'afegeix al senyal
    Pn = Ps / (pRuidoEbNo * bitsSimbolo);
    
    %Longitud del bloc de s�mbols
    %   Es defineix numSymb com el nombre de s�mbols que se simularan a cada iteraci�
    %   del bucle
    numSymb = 10000;    
    
    %Bucle de simulaci�
    %   S'entra en un bucle que continuar� simulant blocs de transmissi� fins
    %   que:
    %       - S'hagin acumulat almenys maxNumErrs errors
    %       - S'hagin transm�s almenys maxNumBits
    %   Aquest m�tode de parada (criteri d'error o de bits) �s t�pic a
    %   simulacions Monte Carlo per garantir resultats estad�sticament
    %   significatius sense excedir temps de processament excessius
    while((totErr < maxNumErrs) && (numBits < maxNumBits))
    
        % Check if the user clicked the Stop button of BERTool.
        % ==== DO NOT MODIFY ====
    
        %Detecci� de parada manual
       %   Es comprova si l'usuari ha sol�licitat detenir la simulaci�
       %   Si �s aix� surt del bucle
        if isBERToolSimulationStopped()
            break
        end
        % ==== END of DO NOT MODIFY ====
      
        % --- Proceed with simulation.
        % --- Be sure to update totErr and numBits.
        % --- INSERT YOUR CODE HERE.
    
        %Generaci� de s�mbols a transmetre
        %   Es genera un vector de numSymb nombres sencers aleatoris entre 1 i cantidadSimbolos
        %   Cada nombre representa l'�ndex d'un s�mbol de la constel�laci�
        %   La generaci� aleat�ria assegura que cada s�mbol es transmeti amb
        %   una igual probabilitat, simulant una font d'informaci� equiprobable
        txSymb = randi([1 cantidadSimbolos], 1, numSymb);      %vector de los indices de los simbolos que queremos enviar
    
        %Mapeig d'�ndex a s�mbols
        %   S'utilitza el vector 'txSymb' per seleccionar els s�mbols
        %   corresponents de 'contel_symb'
        %   Aix� genera el vector del senyal transm�s, on cada posici� cont�
        %   un valor complex de la constel�laci�
        txSig = constelSymb(txSymb);
        
    
        %Generaci� del soroll AWGN
        %   Es genera un vector de soroll complex
        %   randn(1, numSymb) produeix numSymb mostres de soroll gaussi� real amb mitja 0 i
        %   vari�ncia 1
        %   Es genera soroll per les parts real i imagin�ria, i es multiplica
        %   per (PN/2)^(1/2) per ajustar la vari�ncia de cada component
        %   En un canal AWGN, el soroll es complex, i la pot�ncia total es
        %   reparteix equitativament entre la part real i la part imagin�ria
        Soroll = sqrt(Pn / 2) * (randn( 1, numSymb) + 1i * randn( 1, numSymb)); 
    
        %Senyal rebut
        %   El senyal rebut rxSig �s la suma del senyal transm�s (convertida en
        %   vector columna amb la transposici� ') i el soroll generat
        %   Aix� simula el pas del senyal per un canal AWGN, on s'afegeix
        %   soroll blanc gaussi� al senyal transm�s
        rxSig =  txSig.' + Soroll; 
        
        %Demodulaci� i c�lcul d'errors
        %   Es truca a la funci� demodqam per demodular el senyal rebut
        %   La funci� compara el senal rebut rxSig amb la constel�laci� definida
        %   (constel_symb) i el mapeig de bits (constel_bits)
        %   Es calcula el nombre d'errors (nerrors) comparant els bits del
        %   s�mbol transm�s (fent servir txSymb) amb els bits detectats
        %   La demodulaci� per m�nima dist�ncia (o detector de m�xima
        %   versemblan�a) �s el m�tode que es fa servir per decidir quin va ser
        %   el s�mbol transm�s a partir del senyal amb soroll
    
        [detSym_idx, nerrors] = demodqam(rxSig, constelSymb, constelBits, txSymb);
    
        %Acumulaci� de bits transmesos
        %   S'incrementa el comptador total de bits simulats a la quantitat
        %   corresponent al bloc actual 'nbitsBloc'
        %   Aix� permet calcular la taxa d'error com la relaci� entre errors i
        %   bits totals processats
        %   Aix� permet calcular la taxa d'error com la relaci� entre errors i
        %   bits totals processats
        numBits = numBits + nbitsBloc;
    
        %Acumulaci� d'errors
        %   S'actualitza el comptador total d'errors sumant els errors
        %   detectats en aquest bloc
        totErr = totErr + nerrors;
        
    end
    
    %C�lcul final del BER
    %   Es calcula la taxa d'error de bits (BER) dividint el n�mero total
    %   d'errors acumulats entre el nombre total de bits simulats
    %   El BER �s una mesura fonamental a comunicacions digitals, indicant la
    %   fracci� de bits erronis rebuts. Un BER menor indica un sistema m�s.
    %   robust enfront del soroll
    ber = totErr/numBits;