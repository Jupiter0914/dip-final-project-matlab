function tests=testEvaluation
tests=functiontests(localfunctions);
end

function testDeadlinesAndTiming(testCase)
raw=false(10);raw(3:7,3:6)=true;
[t,e]=measureEncoding(raw,128,'cross',0,8);
verifyEqual(testCase,t.status,'success')
verifyNumElements(testCase,e,1)
verifyGreaterThanOrEqual(testCase,e.received_ms,e.serialized_ms)
verifyGreaterThanOrEqual(testCase,t.return_ms,e.received_ms)
s=pixelScores(raw,decodePM31(e.bytes));verifyEqual(testCase,e.xor,s.xor)
[t,e]=measureEncoding(raw,10,'seed',200,8);
verifyEmpty(testCase,e);verifyEqual(testCase,t.status,'below_proved_lower_bound')
end

function testPairingAndMissing(testCase)
%构造两个来源，故意制造缺失和不同码长以检查等源权重
dataset=repmat("Oxford",24,1);id=repelem(["a";"b"],12);session=repmat(repelem((1:3)',4),2,1);
rep=repmat([1;1;2;2],6,1);method=repmat(["cross";"within_full"],12,1);
budget=repmat(256,24,1);deadline=repmat(100,24,1);rings=repmat(2,24,1);
status=repmat("success",24,1);nbytes=repmat(254,24,1);
x=repmat([10;11],12,1);x(1)=0;x(3)=8;status(4)="not_ready";nbytes(5)=250;
fp=x;fn=0*x;iou=ones(size(x));rmse=0*x;
obs=table(dataset,id,session,rep,budget,deadline,method,rings,status,nbytes,x,fp,fn,iou,rmse);
obs.Properties.VariableNames{11}='xor';
manifest=table(["a";"b"],["Oxford";"Oxford"],["a";"b"],'VariableNames',{'id','dataset','category'});
[src,summary]=pairedStats(obs,manifest);
verifyEqual(testCase,src.n_pairs,[4;6])
verifyEqual(testCase,src.gain,[(11+1+1)/3;1],'AbsTol',1e-12)
v=summary(summary.scope=="R2+",:);
verifyEqual(testCase,v.mean_gain,8/3,'AbsTol',1e-12)
verifyEqual(testCase,v.n_complete,1)
end

